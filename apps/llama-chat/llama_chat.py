"""llama-chat: the logic of the story teller for the N900 (no GUI here, so it can be tested on a PC).

The engine is llama2c (llama2.c, one C file) started as a child process: its standard output is the story, token by token; its standard error
ends with "achieved tok/s: N". The models are files in ~/MyDocs/llama2c on the memory card (or ~/llama2c, see default_models_dir; the folder that the terminal launcher llama-story uses as well); the catalogue
of the models that can be downloaded is models.json next to this file, and ~/.llama-chat/models.json adds your own entries (same fields).
A model that is not in llama2.c format but a Hugging Face safetensors checkpoint has a "convert" block: the files are downloaded and
st2llama2c.py (pure Python) writes the .bin.
"""
import codecs, hashlib, json, os, re, shutil, subprocess, sys, threading, time

HERE = os.path.dirname(os.path.realpath(__file__))
HOME = os.environ.get("HOME", "/home/user")
DIR = os.environ.get("LLAMACHAT_DIR") or os.path.join(HOME, ".llama-chat")
OLD_MODELS_DIR = os.path.join(HOME, "llama2c")          # where the models used to be kept (the 2 GB system partition: it fills up)


def default_models_dir(home=HOME, mounted=os.path.ismount):
    """The models are big, so they go to the memory card (MyDocs, tens of GB) when it is there; the 2 GB partition of the system (/home and /opt) is nearly full
    on a phone that has many packages. An unmounted card (USB storage mode) is only an empty folder on that partition, so it must not be used."""
    card = os.path.join(home, "MyDocs")
    return os.path.join(card, "llama2c") if mounted(card) else os.path.join(home, "llama2c")


MODELS_DIR = os.environ.get("LLAMACHAT_MODELS") or default_models_dir()
ENGINE = os.environ.get("LLAMACHAT_ENGINE", "/opt/llama2c/bin/llama2c")
SHARE = os.environ.get("LLAMACHAT_SHARE", "/opt/llama2c/share/llama2c")
CONVERTER = os.environ.get("LLAMACHAT_CONVERTER") or next(
    (p for p in (os.path.join(HERE, "st2llama2c.py"), os.path.join(HERE, "..", "llama2c", "tools", "st2llama2c.py")) if os.path.exists(p)),
    os.path.join(HERE, "st2llama2c.py"))
CURL = os.environ.get("LLAMACHAT_CURL", "curl")
PYTHON = os.environ.get("LLAMACHAT_PYTHON") or sys.executable
RAM_LIMIT = int(os.environ.get("LLAMACHAT_RAM_LIMIT", str(160 * 1024 * 1024)))   # bigger weights do not fit in the RAM of the N900 without swapping
SETTINGS = os.path.join(DIR, "settings.json")

DEFAULTS = {"model": "stories15M", "temperature": 0.8, "topp": 0.9, "tokens": 200, "memory": 60}
LIMITS = {"temperature": (0.1, 1.5), "topp": (0.1, 1.0), "tokens": (16, 400), "memory": (0, 150)}


# ---- settings ------------------------------------------------------------------------------------------------------------------------------

def load_settings():
    s = dict(DEFAULTS)
    try:
        saved = json.load(open(SETTINGS, encoding="utf-8"))
    except (OSError, ValueError):
        saved = {}
    if isinstance(saved, dict):
        for k, v in saved.items():
            if k == "model" and isinstance(v, str):
                s[k] = v
            elif k in LIMITS and isinstance(v, (int, float)) and not isinstance(v, bool):
                lo, hi = LIMITS[k]
                s[k] = type(DEFAULTS[k])(min(hi, max(lo, v)))
    return s


def save_settings(s):
    os.makedirs(DIR, exist_ok=True)
    tmp = SETTINGS + ".new"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(s, f, indent=1)
    os.replace(tmp, SETTINGS)


# ---- the models -----------------------------------------------------------------------------------------------------------------------------

def load_models():
    """The catalogue: models.json of the package, then the entries of ~/.llama-chat/models.json (an entry with the same id replaces it)."""
    out = {}
    for path in (os.path.join(HERE, "models.json"), os.path.join(DIR, "models.json")):
        try:
            for m in json.load(open(path, encoding="utf-8")):
                if isinstance(m, dict) and m.get("id") and m.get("file"):
                    out[m["id"]] = m
        except (OSError, ValueError):
            pass
    return list(out.values())


def model_path(m):
    """The file of a model: in the models folder, or (a phone that has the models from before) in ~/llama2c; new downloads go to the models folder."""
    if m.get("bundled"):
        return os.path.join(SHARE, m["file"])
    new = os.path.join(MODELS_DIR, m["file"])
    old = os.path.join(OLD_MODELS_DIR, m["file"])
    return old if not os.path.exists(new) and os.path.exists(old) and os.path.realpath(old) != os.path.realpath(new) else new


def tokenizer_path(m):
    return os.path.join(SHARE, m.get("tokenizer", "tokenizer.bin"))


def installed(m):
    try:
        size = os.path.getsize(model_path(m))
    except OSError:
        return False
    return size > 0 and (not m.get("size") or size == m["size"])


def fits(m):
    return m.get("size", 0) <= RAM_LIMIT


WORK_BYTES = 24 * 1024 * 1024        # what the engine needs besides the weights (the activations, the key-value cache, the tokenizer)


def ram_free_bytes(path="/proc/meminfo"):
    """The memory that could hold the weights: free + buffers + cached (the cache is given up on demand); None when it cannot be read."""
    try:
        with open(path) as f:
            kb = {k: int(v.split()[0]) for k, v in (ln.split(":", 1) for ln in f if ":" in ln)}
        return (kb["MemFree"] + kb.get("Buffers", 0) + kb.get("Cached", 0)) * 1024
    except (OSError, ValueError, KeyError):
        return None


def missing_ram(m, free=None):
    """Bytes of memory that are missing for the weights of a model to sit in the RAM at once (the models are read from the memory card by mapping the file:
    when they do not fit, every token reads parts of the file from the card again and the speed drops to a half or less); 0 when they fit or the memory is
    not known."""
    free = ram_free_bytes() if free is None else free
    if free is None:
        return 0
    return max(0, m.get("size", 0) + WORK_BYTES - free)


def fmt_size(n):
    return "%.1f MB" % (n / 1048576.0) if n >= 1048576 else "%d kB" % max(1, n // 1024)


def describe(m):
    """One line for the list: size, speed, state."""
    state = "installed" if installed(m) else ("too big for the RAM" if not fits(m) else "not downloaded")
    parts = [fmt_size(m.get("size", 0)), "%s tok/s" % ("%g" % m["speed"]) if m.get("speed") else "", state]
    return " · ".join(p for p in parts if p)


def need_bytes(m):
    """Free space needed to download the model (a converted one needs the checkpoint and the result at the same time)."""
    conv = m.get("convert")
    return int((m.get("size", 0) + (sum(f.get("size", 0) for f in conv["files"]) if conv else 0)) * 1.05)


def free_bytes():
    os.makedirs(MODELS_DIR, exist_ok=True)
    st = os.statvfs(MODELS_DIR)
    return st.f_bavail * st.f_frsize


def delete_model(m):
    for p in {model_path(m), model_path(m) + ".part", os.path.join(MODELS_DIR, m["file"]), os.path.join(MODELS_DIR, m["file"]) + ".part"}:
        try:
            os.remove(p)
        except OSError:
            pass
    shutil.rmtree(os.path.join(MODELS_DIR, ".work", m["id"]), ignore_errors=True)


# ---- the prompt and the story ---------------------------------------------------------------------------------------------------------------

def build_prompt(story, user_text, memory):
    """The model only continues a text, so the prompt is the end of the story so far (the last `memory` words) and what the user wrote."""
    tail = " ".join(story.split()[-memory:]) if memory > 0 else ""
    return (tail + " " + user_text.strip()).strip()


def engine_command(m, s, prompt):
    """The engine is told to stop after the prompt and `tokens` more tokens (the prompt is a guess at its length in tokens: the engine counts both)."""
    chars_per_token = 1.2 if m.get("tokenizer") == "tok512.bin" else 2.5
    steps = int(len(prompt.encode("utf-8")) / chars_per_token) + 2 + int(s["tokens"])
    return [ENGINE, model_path(m), "-z", tokenizer_path(m), "-t", "%g" % s["temperature"], "-p", "%g" % s["topp"], "-n", str(steps), "-i", prompt]


class Streamer:
    """The engine prints the prompt back as it reads it; feed() drops that echo and gives the new text (the bytes are cut anywhere)."""

    def __init__(self, prompt):
        self.prompt = re.sub(r"\s+", "", prompt).lower()
        self.dec = codecs.getincrementaldecoder("utf-8")("replace")
        self.buf = ""
        self.echo_done = not self.prompt

    def feed(self, data, final=False):
        text = self.dec.decode(data, final)
        if self.echo_done:
            return text
        self.buf += text
        n = len(self.prompt)
        seen = 0                                   # characters of the prompt matched so far, ignoring white space
        for i, ch in enumerate(self.buf):
            if ch.isspace():
                continue
            if seen < n and ch.lower() == self.prompt[seen]:
                seen += 1
                if seen == n:
                    self.echo_done = True
                    rest, self.buf = self.buf[i + 1:], ""
                    return rest
            else:                                  # it does not echo the prompt (another tokenizer): show everything
                self.echo_done = True
                out, self.buf = self.buf, ""
                return out
        if final:
            self.echo_done = True
            out, self.buf = self.buf, ""
            return out
        return ""


class Generation:
    """One run of the engine. poll() is called from a timer of the GUI: it never blocks."""

    def __init__(self, cmd, prompt):
        os.makedirs(DIR, exist_ok=True)
        self.errpath = os.path.join(DIR, "engine.err")
        self.err = open(self.errpath, "w")
        self.stream = Streamer(prompt)
        self.proc = subprocess.Popen(cmd, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=self.err,
                                     preexec_fn=lambda: os.nice(5))                 # the window should stay responsive
        os.set_blocking(self.proc.stdout.fileno(), False)
        self.started = time.time()
        self.speed = None
        self.error = None
        self.stopped = False
        self.finished = False

    def poll(self):
        """-> (new text, finished)"""
        out = ""
        while not self.finished:
            try:
                data = os.read(self.proc.stdout.fileno(), 4096)
            except BlockingIOError:
                break
            except OSError:
                data = b""
            if not data:                                                          # end of the stream: the engine has exited
                self.proc.wait()
                out += self.stream.feed(b"", True)
                self._finish()
                break
            out += self.stream.feed(data)
        return out, self.finished

    def _finish(self):
        self.finished = True
        self.err.close()
        self.proc.stdout.close()
        try:
            err = open(self.errpath, errors="replace").read()
        except OSError:
            err = ""
        m = re.search(r"achieved tok/s:\s*([0-9.]+)", err)
        if m:
            self.speed = float(m.group(1))
        if self.proc.returncode not in (0, None) and not self.stopped:
            self.error = (err.strip().splitlines() or ["the engine failed (code %d)" % self.proc.returncode])[-1]

    def stop(self):
        if not self.finished:
            self.stopped = True
            self.proc.terminate()


# ---- downloads ------------------------------------------------------------------------------------------------------------------------------

def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for block in iter(lambda: f.read(1 << 20), b""):
            h.update(block)
    return h.hexdigest()


class Job:
    """Download of a model (and its conversion): a chain of child processes, advanced by poll() from a timer; one step at a time.
    poll() -> (finished, fraction 0..1, text, error or None)"""

    def __init__(self, m):
        self.m = m
        self.final = model_path(m)
        os.makedirs(MODELS_DIR, exist_ok=True)
        conv = m.get("convert")
        self.work = os.path.join(MODELS_DIR, ".work", m["id"])
        self.steps = []                                  # (kind, ...)
        if conv:
            os.makedirs(self.work, exist_ok=True)
            for f in conv["files"]:
                self.steps.append(("get", f["url"], os.path.join(self.work, f["name"]), f.get("size", 0), f.get("sha256")))
            self.steps.append(("convert",))
        else:
            self.steps.append(("get", m["url"], self.final, m.get("size", 0), m.get("sha256")))
        self.total = sum(s[3] for s in self.steps if s[0] == "get") or 1
        self.done_bytes = 0
        self.proc = None
        self.step = None
        self.verify = None                               # the thread that hashes a downloaded file
        self.error = None
        self.cancelled = False

    def _part(self, dest):
        return dest + ".part"

    def _start(self):
        step = self.steps.pop(0)
        self.step = step
        if step[0] == "get":
            part = self._part(step[2])
            self.proc = subprocess.Popen([CURL, "-fsSL", "--retry", "3", "--connect-timeout", "30", "-C", "-", "-o", part, step[1]],
                                         stdin=subprocess.DEVNULL, stderr=subprocess.PIPE)
        else:
            self.proc = subprocess.Popen([PYTHON, CONVERTER, self.work, self.final, "--seq-len", "512"], stdin=subprocess.DEVNULL,
                                         stdout=subprocess.PIPE, stderr=subprocess.STDOUT, preexec_fn=lambda: os.nice(5))

    def poll(self):
        while True:
            if self.error or self.cancelled:
                return True, 0.0, "", self.error
            if self.verify is not None:                   # hashing a finished download
                if self.verify["thread"].is_alive():
                    return False, self._fraction(1.0), "checking the download", None
                ok, path, self.verify = self.verify["ok"], self.verify["path"], None
                if not ok:
                    self.error = "the downloaded file is damaged (the checksum differs)"
                    try:
                        os.remove(path)
                    except OSError:
                        pass
                    continue
                self.done_bytes += self.step[3]
                self.proc = None
            if self.proc is None:
                if not self.steps:
                    shutil.rmtree(self.work, ignore_errors=True)
                    return True, 1.0, "", None
                self._start()
            code = self.proc.poll()
            if code is None:
                if self.step[0] == "get":
                    try:
                        got = os.path.getsize(self._part(self.step[2]))
                    except OSError:
                        got = 0
                    return False, self._fraction(got / (self.step[3] or got or 1)), "downloading", None
                return False, 0.95, "converting", None
            if code != 0:
                pipe = self.proc.stderr if self.step[0] == "get" else self.proc.stdout
                err = pipe.read().decode("utf-8", "replace").strip()
                self.error = (err.splitlines() or ["failed (code %d)" % code])[-1]
                continue
            if self.step[0] == "convert":
                self.proc = None
                continue
            dest, size, sha = self.step[2], self.step[3], self.step[4]      # a download is complete: the .part gets its real name
            os.replace(self._part(dest), dest)
            if size and os.path.getsize(dest) != size:
                self.error = "the downloaded file has the wrong size"
                os.remove(dest)
                continue
            if sha:
                box = {"ok": False, "path": dest}
                box["thread"] = threading.Thread(target=lambda: box.update(ok=(sha256_file(dest) == sha)), daemon=True)
                self.verify = box
                box["thread"].start()
            else:
                self.done_bytes += size
                self.proc = None

    def _fraction(self, within):
        cur = self.step[3] if self.step and self.step[0] == "get" else 0
        return min(0.9, (self.done_bytes + cur * min(1.0, within)) / self.total * 0.9)

    def cancel(self):
        self.cancelled = True
        if self.proc and self.proc.poll() is None:
            self.proc.terminate()
        for s in [self.step] if self.step else []:
            if s[0] == "get":
                try:
                    os.remove(self._part(s[2]))
                except OSError:
                    pass
        shutil.rmtree(self.work, ignore_errors=True)
