"""notpipe-hildon: the logic of the YouTube client for the N900 (no GUI here, so it can be tested on a PC).

The idea is the one of notPipe (Android, https://github.com/gohoski/notPipe): the phone does not talk to YouTube but to an Invidious instance, a public
server that has an API (search, the list of streams of a video). The instances come and go, so there is a list of them (a small bundled one,
refreshed from https://api.invidious.io/); a call tries one after another until an instance answers with JSON. An instance that wants a browser check
(some do) answers with an HTML page: it is skipped, never worked around.

YouTube no longer offers pictures and sound together: the picture (H.264 in MP4, 240p or 360p is what the N900 can decode) and the sound (AAC) are
two files. They are downloaded with curl into a cache and played together by nplay (our player), which takes the two files as they are.
"Download" joins them with ffmpeg (no re-encoding) into one MP4 in MyDocs/Videos (and does not play it); a video that is already there is played from there.
"""
import json, os, random, re, shutil, subprocess, threading, time, urllib.parse

HERE = os.path.dirname(os.path.realpath(__file__))
HOME = os.environ.get("HOME", "/home/user")
DIR = os.environ.get("NOTPIPE_DIR") or os.path.join(HOME, ".notpipe")
SAVE_DIR = os.environ.get("NOTPIPE_SAVE") or os.path.join(HOME, "MyDocs", "Videos")           # MyDocs is the big card; the home folder is small
CACHE = os.environ.get("NOTPIPE_CACHE") or os.path.join(SAVE_DIR, "NotPipe cache")          # the downloaded streams and the thumbnails: visible in the file manager
OLD_CACHE = os.path.join(HOME, "MyDocs", ".notpipe")                                           # where the first versions kept them
CURL = os.environ.get("NOTPIPE_CURL", "curl")
PLAYER = os.environ.get("NOTPIPE_PLAYER", "/usr/bin/nplay")
FFMPEG = os.environ.get("NOTPIPE_FFMPEG", "/usr/bin/ffmpeg")
INSTANCE_SOURCE = os.environ.get("NOTPIPE_INSTANCE_SOURCE", "https://api.invidious.io/instances.json?sort_by=type,users")
SETTINGS = os.path.join(DIR, "settings.json")
INSTANCE_CACHE = os.path.join(DIR, "instances.json")
USER_AGENT = "notpipe-hildon/0.1 (Maemo 5)"
INSTANCE_MAX_AGE = 24 * 3600
CHUNK = 4 * 1024 * 1024                              # a stream is downloaded in pieces of this size (Range requests): one long request is throttled to a trickle
TRIES = 5                                           # how many instances one call tries

DEFAULTS = {"quality": 240, "audio": 140, "cache_mb": 400}
CHOICES = {"quality": (144, 240, 360, 480), "audio": (140, 139)}       # audio: itag 140 = AAC 128 kbit/s, 139 = HE-AAC 48 kbit/s
LIMITS = {"cache_mb": (50, 4000)}


class ApiError(Exception):
    """A call to an instance failed (the text is meant for the user)."""


# ---- settings ------------------------------------------------------------------------------------------------------------------------------

def load_settings():
    s = dict(DEFAULTS)
    try:
        saved = json.load(open(SETTINGS, encoding="utf-8"))
    except (OSError, ValueError):
        saved = {}
    if isinstance(saved, dict):
        for k, v in saved.items():
            if k in CHOICES and v in CHOICES[k]:
                s[k] = v
            elif k in LIMITS and isinstance(v, int) and not isinstance(v, bool):
                lo, hi = LIMITS[k]
                s[k] = min(hi, max(lo, v))
    return s


def save_settings(s):
    os.makedirs(DIR, exist_ok=True)
    tmp = SETTINGS + ".new"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(s, f, indent=1)
    os.replace(tmp, SETTINGS)


# ---- formatting ----------------------------------------------------------------------------------------------------------------------------

def fmt_duration(sec):
    sec = int(sec or 0)
    h, rest = divmod(sec, 3600)
    m, s = divmod(rest, 60)
    return "%d:%02d:%02d" % (h, m, s) if h else "%d:%02d" % (m, s)


def fmt_size(n):
    return "%.1f MB" % (n / 1048576) if n >= 1048576 else "%d kB" % max(1, n // 1024)


def fmt_count(n):
    n = int(n or 0)
    if n >= 1000000:
        return "%.1fM" % (n / 1000000)
    if n >= 1000:
        return "%dk" % (n // 1000)
    return str(n)


def safe_name(title, limit=80):
    """A file name for a title: the card of the phone is FAT, so no / \\ : * ? " < > | and no control characters."""
    name = re.sub(r'[\x00-\x1f/\\:*?"<>|]', "_", title or "").strip(" .")
    return (name[:limit].strip(" .")) or "video"


# ---- instances and calls -------------------------------------------------------------------------------------------------------------------

_last_good = None


def bundled_instances():
    """The instances that come with the package (NOTPIPE_INSTANCES=url,url overrides them: for tests and for a server of your own)."""
    if os.environ.get("NOTPIPE_INSTANCES"):
        return [u.strip() for u in os.environ["NOTPIPE_INSTANCES"].split(",") if u.strip()]
    try:
        return [u for u in json.load(open(os.path.join(HERE, "instances.json"), encoding="utf-8")) if isinstance(u, str)]
    except (OSError, ValueError):
        return []


def cached_instances():
    try:
        d = json.load(open(INSTANCE_CACHE, encoding="utf-8"))
        return [u for u in d["instances"] if isinstance(u, str)], float(d.get("time", 0))
    except (OSError, ValueError, KeyError, TypeError):
        return [], 0.0


def instances():
    """The instances to try, best first: the last one that worked, the refreshed list, the bundled ones (no duplicates)."""
    out = []
    for u in ([_last_good] if _last_good else []) + cached_instances()[0] + bundled_instances():
        u = u.rstrip("/")
        if u and u not in out:
            out.append(u)
    return out


def instance_list_is_old():
    return time.time() - cached_instances()[1] > INSTANCE_MAX_AGE


def _curl_json(url, timeout=25):
    """GET a URL and parse the JSON answer. An HTTP error with a JSON body {"error": ...} (what the instances send) gives that text."""
    try:
        p = subprocess.run([CURL, "-sSL", "-m", str(timeout), "--connect-timeout", "15", "-A", USER_AGENT, "-w", "\n%{http_code}", url],
                           stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    except OSError as e:
        raise ApiError("curl could not be started: %s" % e)
    if p.returncode != 0:
        err = (p.stderr.decode("utf-8", "replace").strip().splitlines() or ["curl failed (%d)" % p.returncode])[-1]
        raise ApiError(err)
    body, _, code = p.stdout.rpartition(b"\n")
    try:
        data = json.loads(body.decode("utf-8", "replace"))
    except ValueError:
        data = None
    if isinstance(data, dict) and data.get("error"):
        raise ApiError(str(data["error"])[:120])
    if not code.startswith(b"2"):
        raise ApiError("HTTP " + code.decode("ascii", "replace"))
    if data is None:
        raise ApiError("not an API answer (a browser check page?)")
    return data


def refresh_instances():
    """Download the list of public instances (those that have the API enabled) into ~/.notpipe/instances.json. Returns the list."""
    data = _curl_json(INSTANCE_SOURCE)
    urls = []
    for entry in data if isinstance(data, list) else []:
        try:
            info = entry[1]
            if info.get("type") == "https" and info.get("api") is True and isinstance(info.get("uri"), str):
                urls.append(info["uri"].rstrip("/"))
        except (IndexError, KeyError, AttributeError, TypeError):
            continue
    if not urls:
        raise ApiError("the list of instances is empty")
    os.makedirs(DIR, exist_ok=True)
    tmp = INSTANCE_CACHE + ".new"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump({"time": time.time(), "instances": urls[:30]}, f, indent=1)
    os.replace(tmp, INSTANCE_CACHE)
    return urls[:30]


def current_instance():
    """The instance that answered last (None before the first call)."""
    return _last_good


def call(path, skip=()):
    """GET path (like /api/v1/search?q=...) from the first instance that answers with JSON (not from those in skip). Returns the data;
    ApiError says what every instance said."""
    global _last_good
    failures = []
    for base in [b for b in instances() if b not in skip][:TRIES]:
        try:
            data = _curl_json(base + path)
        except ApiError as e:
            failures.append("%s: %s" % (urllib.parse.urlparse(base).hostname or base, e))
            continue
        _last_good = base
        return data
    raise ApiError("no instance answered. " + ("; ".join(failures) if failures else "the list of instances is empty"))


# ---- search and the streams of a video -----------------------------------------------------------------------------------------------------

VIDEO_ID = re.compile(r"^[A-Za-z0-9_-]{11}$")


def search(query, page=1):
    """A list of {id, title, author, length, views, published} for a query (videos only, no live streams)."""
    data = call("/api/v1/search?q=%s&type=video&page=%d" % (urllib.parse.quote(query), page))
    out = []
    for it in data if isinstance(data, list) else []:
        if not isinstance(it, dict) or it.get("type") != "video" or not VIDEO_ID.match(str(it.get("videoId", ""))):
            continue
        if it.get("liveNow") or it.get("isUpcoming"):
            continue
        out.append({"id": it["videoId"], "title": str(it.get("title", "")), "author": str(it.get("author", "")),
                    "length": int(it.get("lengthSeconds") or 0), "views": int(it.get("viewCount") or 0), "published": str(it.get("publishedText", "")),
                    "thumb": _thumb_url(it.get("videoThumbnails"), _last_good)})
    return out


def _thumb_url(thumbs, base):
    """The URL of a small 16:9 picture (quality "medium", 320x180) of a video from the list of thumbnails; "" when there is none."""
    for want in ("medium", "default"):
        for t in thumbs if isinstance(thumbs, list) else []:
            if isinstance(t, dict) and t.get("quality") == want and isinstance(t.get("url"), str):
                u = t["url"]
                return (base or "") + u if u.startswith("/") else u
    return ""


def _parse_format(f):
    t = str(f.get("type", ""))
    m = re.match(r"(video|audio)/(\w+);\s*codecs=\"([^\"]*)\"", t)
    if not m or not f.get("url"):
        return None
    height = fps = 0
    label = re.match(r"(\d+)p(\d+)?", str(f.get("qualityLabel") or ""))
    if label:
        height = int(label.group(1))
        fps = int(label.group(2) or 30)
    try:
        size = int(f.get("clen") or 0)
    except ValueError:
        size = 0
    return {"kind": m.group(1), "container": m.group(2), "codec": m.group(3), "itag": int(f.get("itag") or 0), "url": f["url"], "size": size,
            "height": height, "fps": fps}


def video_info(vid, skip=()):
    """{id, title, author, length, instance, formats: [...]} of a video (not from the instances in skip)."""
    if not VIDEO_ID.match(vid or ""):
        raise ApiError("not a video id")
    d = call("/api/v1/videos/" + urllib.parse.quote(vid), skip)
    if not isinstance(d, dict):
        raise ApiError("unexpected answer")
    fmts = [x for x in (_parse_format(f) for f in d.get("adaptiveFormats") or [] if isinstance(f, dict)) if x]
    if not fmts:
        raise ApiError("this video has no streams that can be downloaded (a live stream?)")
    return {"id": vid, "title": str(d.get("title", "")), "author": str(d.get("author", "")), "length": int(d.get("lengthSeconds") or 0),
            "instance": _last_good, "formats": fmts}


def pick_streams(info, quality=240, audio=140):
    """(video, audio) formats to download: H.264 in MP4 as high as the quality allows (not above, 30 fps preferred; the lowest one when all are above),
    and the AAC audio of the wanted itag (140 or 139), else any AAC."""
    vids = [f for f in info["formats"] if f["kind"] == "video" and f["container"] == "mp4" and f["codec"].startswith("avc1") and f["height"]]
    if not vids:
        raise ApiError("no H.264 stream in this video")
    fit = [f for f in vids if f["height"] <= quality]
    if fit:
        top = max(f["height"] for f in fit)
        cand = [f for f in fit if f["height"] == top]
    else:
        low = min(f["height"] for f in vids)
        cand = [f for f in vids if f["height"] == low]
    v = sorted(cand, key=lambda f: (f["fps"] > 30, f["fps"]))[0]
    auds = [f for f in info["formats"] if f["kind"] == "audio" and f["container"] == "mp4" and f["codec"].startswith("mp4a")]
    if not auds:
        raise ApiError("no AAC audio stream in this video")
    a = next((f for f in auds if f["itag"] == audio), None) or auds[0]
    return v, a


# ---- tasks (a call in a thread, polled from the GUI) -----------------------------------------------------------------------------------------

class Task:
    """Run fn(*args) in a thread; poll() -> (finished, result, error text or None)."""

    def __init__(self, fn, *args):
        self.result = self.error = None
        self.finished = False
        threading.Thread(target=self._run, args=(fn, args), daemon=True).start()

    def _run(self, fn, args):
        try:
            self.result = fn(*args)
        except ApiError as e:
            self.error = str(e)
        except Exception as e:                        # a bug must not kill the thread silently
            self.error = "%s: %s" % (type(e).__name__, e)
        self.finished = True

    def poll(self):
        return self.finished, self.result, self.error


# ---- the cache and the downloads -----------------------------------------------------------------------------------------------------------

def saved_file(vid):
    """The joined MP4 of a video that was downloaded into the Videos folder ("<title> [<id>].mp4"), or None."""
    suffix = " [%s].mp4" % vid
    try:
        for n in os.listdir(SAVE_DIR):
            if n.endswith(suffix):
                return os.path.join(SAVE_DIR, n)
    except OSError:
        pass
    return None


def saved_ids():
    """The ids of all videos in the Videos folder that nplay's list may mark as downloaded."""
    out = set()
    try:
        for n in os.listdir(SAVE_DIR):
            m = re.search(r" \[([A-Za-z0-9_-]{11})\]\.mp4$", n)
            if m:
                out.add(m.group(1))
    except OSError:
        pass
    return out


def migrate_old_cache():
    """The first versions kept the cache in MyDocs/.notpipe; move it to the visible folder once (when the new one does not exist yet)."""
    if CACHE != os.path.join(SAVE_DIR, "NotPipe cache") or not os.path.isdir(OLD_CACHE) or os.path.exists(CACHE):
        return False
    try:
        os.makedirs(SAVE_DIR, exist_ok=True)
        os.rename(OLD_CACHE, CACHE)
        return True
    except OSError:
        return False


def stream_path(vid, f):
    return os.path.join(CACHE, "%s-%d.mp4" % (vid, f["itag"]))


def meta_path(vid):
    return os.path.join(CACHE, vid + ".json")


def write_meta(info, v, a):
    """Remember what is in the cache for a video (title, streams and their sizes), so that it plays without a call to an instance and can be listed.
    The pairs of other qualities that were downloaded earlier stay in the file."""
    pairs = []
    try:
        with open(meta_path(info["id"])) as f:
            pairs = [x for x in json.load(f).get("pairs", []) if isinstance(x, dict)]
    except (OSError, ValueError, AttributeError):
        pass
    mine = {"v": {k: v[k] for k in ("itag", "size", "height")}, "a": {k: a[k] for k in ("itag", "size")}}
    pairs = [x for x in pairs if x.get("v", {}).get("itag") != v["itag"] or x.get("a", {}).get("itag") != a["itag"]] + [mine]
    data = {"id": info["id"], "title": info["title"], "author": info["author"], "length": info["length"], "pairs": pairs}
    try:
        with open(meta_path(info["id"]) + ".tmp", "w") as f:
            json.dump(data, f)
        os.replace(meta_path(info["id"]) + ".tmp", meta_path(info["id"]))
    except OSError:
        pass


def _complete(vid, f):
    try:
        size = os.path.getsize(stream_path(vid, f))
        return isinstance(f.get("itag"), int) and size == (f.get("size") or size)
    except (OSError, AttributeError):
        return False


def cached_entry(vid, quality=240):
    """(meta, vfmt, afmt) of a video whose two streams are completely in the cache (the highest quality up to the wanted one, else the lowest), or None."""
    if not VIDEO_ID.match(vid or ""):
        return None
    try:
        with open(meta_path(vid)) as f:
            meta = json.load(f)
        pairs = [x for x in meta["pairs"] if _complete(vid, x["v"]) and _complete(vid, x["a"])]
    except (OSError, ValueError, KeyError, TypeError, AttributeError):
        return None
    if not pairs:
        return None
    fit = [x for x in pairs if x["v"].get("height", 0) <= quality]
    best = max(fit, key=lambda x: x["v"].get("height", 0)) if fit else min(pairs, key=lambda x: x["v"].get("height", 0))
    return meta, best["v"], best["a"]


def cached_ids(quality=240):
    """The ids of the videos that are complete in the cache (a quick look: the files of the meta data and the sizes of the streams)."""
    try:
        names = [n[:-5] for n in os.listdir(CACHE) if n.endswith(".json") and VIDEO_ID.match(n[:-5])]
    except OSError:
        return set()
    return {v for v in names if cached_entry(v, quality)}


def cached_videos(quality=240):
    """The videos that can be played without the network, newest first: complete in the cache, then those in the Videos folder (title from the name)."""
    out, seen = [], set()
    try:
        names = [n for n in os.listdir(CACHE) if n.endswith(".json")]
    except OSError:
        names = []
    found = []
    for n in names:
        e = cached_entry(n[:-5], quality)
        if e:
            try:
                found.append((os.path.getmtime(os.path.join(CACHE, n)), e[0]))
            except OSError:
                pass
    for _t, m in sorted(found, key=lambda x: x[0], reverse=True):
        out.append({"id": m["id"], "title": str(m.get("title", "")), "author": str(m.get("author", "")), "length": int(m.get("length") or 0),
                    "views": 0, "published": ""})
        seen.add(m["id"])
    try:
        files = sorted(os.listdir(SAVE_DIR), key=lambda n: os.path.getmtime(os.path.join(SAVE_DIR, n)), reverse=True)
    except OSError:
        files = []
    for n in files:
        m = re.match(r"(.*) \[([A-Za-z0-9_-]{11})\]\.mp4$", n)
        if m and m.group(2) not in seen:
            out.append({"id": m.group(2), "title": m.group(1), "author": "", "length": 0, "views": 0, "published": ""})
            seen.add(m.group(2))
    return out


def cache_files():
    try:
        return [p for p in (os.path.join(CACHE, n) for n in os.listdir(CACHE)) if os.path.isfile(p)]
    except OSError:
        return []


def cache_size():
    total = 0
    for p in cache_files():
        try:
            total += os.path.getsize(p)
        except OSError:
            pass
    return total


def prune_cache(limit_bytes, keep=()):
    """Delete the oldest files of the cache until it fits in limit_bytes (the files in keep stay)."""
    files = []
    for p in cache_files():
        try:
            st = os.stat(p)
        except OSError:
            continue
        files.append((st.st_mtime, st.st_size, p))
    total = sum(f[1] for f in files)
    for _mtime, size, p in sorted(files):
        if total <= limit_bytes:
            break
        if p in keep or any(p == k + ".part" for k in keep):
            continue
        try:
            os.remove(p)
            total -= size
        except OSError:
            pass
    return total


def clear_cache():
    n = 0
    for p in cache_files() + thumb_files():
        try:
            os.remove(p)
            n += 1
        except OSError:
            pass
    return n


THUMB_MAX = 400                                     # thumbnails kept (a few kB each)


def thumb_dir():
    return os.path.join(CACHE, "thumbs")


def thumb_path(vid):
    return os.path.join(thumb_dir(), vid + ".jpg")


def thumb_files():
    try:
        return [os.path.join(thumb_dir(), n) for n in os.listdir(thumb_dir())]
    except OSError:
        return []


class ThumbLoader:
    """Downloads the thumbnails of a list of videos one after another in a thread (curl); poll() gives the ids that arrived since the last call."""

    def __init__(self, items):
        self.items = [(v["id"], v["thumb"]) for v in items if v.get("thumb") and VIDEO_ID.match(v["id"])]
        self.done = []
        self.lock = threading.Lock()
        self.cancelled = False
        threading.Thread(target=self._run, daemon=True).start()

    def _run(self):
        os.makedirs(thumb_dir(), exist_ok=True)
        for vid, url in self.items:
            if self.cancelled:
                return
            path = thumb_path(vid)
            if not os.path.exists(path):
                tmp = path + ".part"
                try:
                    p = subprocess.run([CURL, "-fsSL", "-m", "15", "--connect-timeout", "10", "-A", USER_AGENT, "-o", tmp, url],
                                       stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                    if p.returncode != 0 or not os.path.exists(tmp) or os.path.getsize(tmp) < 100:
                        raise OSError("no picture")
                    os.replace(tmp, path)
                except OSError:
                    try:
                        os.remove(tmp)
                    except OSError:
                        pass
                    continue
            with self.lock:
                self.done.append(vid)
        self._prune()

    @staticmethod
    def _prune():
        files = []
        for p in thumb_files():
            try:
                files.append((os.path.getmtime(p), p))
            except OSError:
                pass
        for _m, p in sorted(files)[:max(0, len(files) - THUMB_MAX)]:
            try:
                os.remove(p)
            except OSError:
                pass

    def poll(self):
        with self.lock:
            out, self.done = self.done, []
        return out

    def cancel(self):
        self.cancelled = True


LAST = os.path.join(DIR, "last.json")


def save_last(query, results, page):
    """Remember the last list of results: the application may be closed (or killed on a low memory) while a video plays."""
    try:
        os.makedirs(DIR, exist_ok=True)
        tmp = LAST + ".new"
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump({"query": query, "page": page, "results": results}, f)
        os.replace(tmp, LAST)
    except OSError:
        pass


def load_last():
    """(query, results, page) of the last search, or ("", [], 0)."""
    try:
        d = json.load(open(LAST, encoding="utf-8"))
        res = [r for r in d["results"] if isinstance(r, dict) and VIDEO_ID.match(str(r.get("id", "")))]
        return str(d.get("query", "")), res, int(d.get("page", 0))
    except (OSError, ValueError, KeyError, TypeError):
        return "", [], 0


def remux_command(vpath, apath, out):
    """The ffmpeg command that joins the picture and the sound into one MP4 without re-encoding (a normal MP4: it starts at once, MyDocs-friendly)."""
    return [FFMPEG, "-v", "error", "-y", "-i", vpath, "-i", apath, "-map", "0:v:0", "-map", "1:a:0", "-c", "copy", "-movflags", "+faststart", out]


class Job:
    """The download of the two streams (and the joining into one file when save_to is given): child processes advanced by poll() from a timer.
    poll() -> (finished, fraction 0..1, text, error or None). Complete files already in the cache are not downloaded again."""

    def __init__(self, vid, vfmt, afmt, save_to=None):
        self.vpath, self.apath = stream_path(vid, vfmt), stream_path(vid, afmt)
        self.save_to = save_to
        os.makedirs(CACHE, exist_ok=True)
        self.steps = []
        for f, path in ((vfmt, self.vpath), (afmt, self.apath)):
            if not (os.path.exists(path) and (not f["size"] or os.path.getsize(path) == f["size"])):
                self.steps.append(("get", f["url"], path, f["size"]))
            else:
                os.utime(path)                                      # used just now: the pruning keeps it
        if save_to:
            self.steps.append(("remux",))
        self.total = sum(s[3] for s in self.steps if s[0] == "get") or 1
        self.done_bytes = 0
        self.proc = self.step = None
        self.chunk_end = 0
        self.error = None
        self.cancelled = False

    def _chunk(self):
        """Start the download of the next piece of the stream of the current step (appended to the .part file)."""
        _kind, url, dest, size = self.step
        part = dest + ".part"
        off = os.path.getsize(part) if os.path.exists(part) else 0
        out = open(part, "ab")
        try:
            if size:
                self.chunk_end = min(off + CHUNK, size)
                cmd = [CURL, "-fsSL", "--retry", "3", "--connect-timeout", "30", "-A", USER_AGENT, "-r", "%d-%d" % (off, self.chunk_end - 1), url]
            else:                                                  # the size is not known: one request
                self.chunk_end = 0
                cmd = [CURL, "-fsSL", "--retry", "3", "--connect-timeout", "30", "-A", USER_AGENT, url]
            self.proc = subprocess.Popen(cmd, stdin=subprocess.DEVNULL, stdout=out, stderr=subprocess.PIPE)
        finally:
            out.close()

    def _start(self):
        step = self.steps.pop(0)
        self.step = step
        if step[0] == "get":
            part = step[2] + ".part"
            if not step[3] and os.path.exists(part):
                os.remove(part)                                    # no size to resume from
            if step[3] and os.path.exists(part) and os.path.getsize(part) >= step[3]:        # the whole file is there from an earlier try
                self.proc = subprocess.Popen(["true"])
                return
            self._chunk()
        else:
            os.makedirs(os.path.dirname(self.save_to), exist_ok=True)
            self.proc = subprocess.Popen(remux_command(self.vpath, self.apath, self.save_to + ".part.mp4"), stdin=subprocess.DEVNULL,
                                         stdout=subprocess.PIPE, stderr=subprocess.STDOUT)

    def poll(self):
        while True:
            if self.error or self.cancelled:
                return True, 0.0, "", self.error
            if self.proc is None:
                if not self.steps:
                    return True, 1.0, "", None
                self._start()
            code = self.proc.poll()
            if code is None:
                if self.step[0] == "get":
                    try:
                        got = os.path.getsize(self.step[2] + ".part")
                    except OSError:
                        got = 0
                    return False, min(1.0, (self.done_bytes + got) / self.total), "downloading", None
                return False, 0.97, "joining", None
            if code != 0:
                pipe = self.proc.stderr if self.step[0] == "get" else self.proc.stdout
                err = (pipe.read().decode("utf-8", "replace").strip().splitlines() or ["failed (code %d)" % code])[-1] if pipe else "failed (code %d)" % code
                self.error = err
                continue
            if self.step[0] == "get":
                dest, size = self.step[2], self.step[3]
                part = dest + ".part"
                got = os.path.getsize(part)
                if size and self.chunk_end and got != self.chunk_end:
                    self.error = ("the download is incomplete (%d of %d bytes)" if got < self.chunk_end else
                                  "the server did not honour the range request (%d, expected %d bytes)") % (got, self.chunk_end)
                    continue
                if size and os.path.getsize(part) < size:               # the next piece
                    self._chunk()
                    continue
                if size and os.path.getsize(part) != size:
                    self.error = "the download is incomplete (%d of %d bytes)" % (os.path.getsize(part), size)
                    continue
                os.replace(part, dest)
                self.done_bytes += size or os.path.getsize(dest)
            else:
                os.replace(self.save_to + ".part.mp4", self.save_to)
                for part in (self.vpath, self.apath):                  # the joined file has all of it: the two streams are not needed any more
                    try:
                        os.remove(part)
                    except OSError:
                        pass
            self.proc = None

    def cancel(self):
        self.cancelled = True
        if self.proc and self.proc.poll() is None:
            self.proc.terminate()
        if self.step and self.step[0] == "get":
            for suffix in (".part",):
                try:
                    os.remove(self.step[2] + suffix)
                except OSError:
                    pass


class Playback:
    """Everything between a tap on a video and the picture: the streams (a call), the download (a Job), then the caller starts the Player (or
    the file is saved). poll() -> (finished, fraction 0..1, text, error or None); when finished without error vpath/apath (and saved_to) are set."""

    def __init__(self, vid, settings, save=False, title=""):
        self.vid, self.settings, self.save, self.title = vid, settings, save, title
        self.local = None if save else saved_file(vid)         # watching a video that was downloaded: play that file, no network
        self.cached = None if (save or self.local) else cached_entry(vid, settings["quality"])    # complete in the cache: no call, no download
        self.task = None if (self.local or self.cached) else Task(video_info, vid)
        self.bad = set()                                # instances whose links the download refused (HTTP 403): the next try asks another one
        self.job = None
        self.vpath = self.apath = self.saved_to = None
        self.info = None
        self.picked = None
        self.cancelled = False

    def poll(self):
        if self.cancelled:
            return True, 0.0, "", "cancelled"
        if self.local:
            self.vpath = self.apath = self.local
            return True, 1.0, "", None
        if self.cached:
            _meta, v, a = self.cached
            self.vpath, self.apath = stream_path(self.vid, v), stream_path(self.vid, a)
            for p in (self.vpath, self.apath, meta_path(self.vid)):
                try:
                    os.utime(p)                                     # used just now: the pruning keeps it
                except OSError:
                    pass
            return True, 1.0, "", None
        if self.job is None:
            done, info, err = self.task.poll()
            if not done:
                return False, 0.0, "looking up the video", None
            if err:
                return True, 0.0, "", err
            self.info = info
            try:
                self.picked = pick_streams(info, self.settings["quality"], self.settings["audio"])
            except ApiError as e:
                return True, 0.0, "", str(e)
            keep = tuple(stream_path(self.vid, f) for f in self.picked)
            prune_cache(self.settings["cache_mb"] * 1048576 - sum(f["size"] for f in self.picked), keep)
            if self.save:
                self.saved_to = os.path.join(SAVE_DIR, "%s [%s].mp4" % (safe_name(self.title or info["title"]), self.vid))
            try:
                self.job = Job(self.vid, self.picked[0], self.picked[1], self.saved_to)
            except OSError as e:
                return True, 0.0, "", "cannot use the cache folder: %s" % e
        finished, frac, text, err = self.job.poll()
        if finished and err and "403" in err and not self.cancelled:       # YouTube refuses the links of this instance: ask another one
            self.bad.add(self.info.get("instance"))
            global _last_good
            _last_good = None
            if len(self.bad) < TRIES and [b for b in instances() if b not in self.bad]:
                self.task, self.job = Task(video_info, self.vid, tuple(self.bad)), None
                return False, 0.0, "looking up the video", None
            err = "YouTube refuses the download of this video from every instance (HTTP 403)"
        if finished and not err:
            self.vpath, self.apath = self.job.vpath, self.job.apath
            if not self.save:
                write_meta(self.info, self.picked[0], self.picked[1])
        return finished, frac, text, err

    def cancel(self):
        self.cancelled = True
        if self.job:
            self.job.cancel()


class Player:
    """nplay as a child process. poll() -> None while it runs, else (exit code, the last line of its messages)."""

    def __init__(self, vpath, apath):
        self.proc = subprocess.Popen([PLAYER, vpath, apath], stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)

    def poll(self):
        code = self.proc.poll()
        if code is None:
            return None
        err = self.proc.stderr.read().decode("utf-8", "replace").strip().splitlines()
        return code, (err[-1] if err else "")

    def stop(self):
        if self.proc.poll() is None:
            self.proc.terminate()
