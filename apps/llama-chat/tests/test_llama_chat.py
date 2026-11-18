"""Tests of the logic of llama-chat (no GUI): python3 tests/test_llama_chat.py. Uses a fake engine and file:// downloads; needs curl."""
import array, hashlib, json, os, struct, sys, tempfile, time, unittest

HERE = os.path.dirname(os.path.realpath(__file__))
TMP = tempfile.mkdtemp(prefix="llama-chat-test-")
os.environ.update(LLAMACHAT_DIR=os.path.join(TMP, "cfg"), LLAMACHAT_MODELS=os.path.join(TMP, "models"), LLAMACHAT_SHARE=os.path.join(TMP, "share"),
                  LLAMACHAT_ENGINE=os.path.join(TMP, "engine.py"), HOME=TMP)
os.makedirs(os.environ["LLAMACHAT_SHARE"])
sys.path.insert(0, os.path.join(HERE, ".."))
import llama_chat as L

FAKE = '''#!%s
import sys, time
a = sys.argv
prompt = a[a.index("-i") + 1]
sys.stdout.write(prompt.title()); sys.stdout.flush()      # the engine prints the prompt back, here with other capital letters
for w in ["  and", " the", " r", "obot", " s\\u00e1ng", " a", " song", "."]:
    time.sleep(0.01); sys.stdout.write(w); sys.stdout.flush()
sys.stderr.write("achieved tok/s: 3.250000\\n")
''' % sys.executable
open(L.ENGINE, "w").write(FAKE)
os.chmod(L.ENGINE, 0o755)


def run(gen, limit=10):
    text, end = "", time.time() + limit
    while time.time() < end:
        t, done = gen.poll()
        text += t
        if done:
            return text
        time.sleep(0.005)
    raise AssertionError("the engine did not finish")


def make_safetensors(path, tensors):
    """tensors: {name: (shape, floats)}, F32."""
    head, blob, off = {}, b"", 0
    for name, (shape, vals) in tensors.items():
        raw = array.array("f", vals).tobytes()
        head[name] = {"dtype": "F32", "shape": list(shape), "data_offsets": [off, off + len(raw)]}
        blob += raw
        off += len(raw)
    h = json.dumps(head).encode()
    with open(path, "wb") as f:
        f.write(struct.pack("<Q", len(h)) + h + blob)


class Settings(unittest.TestCase):
    def test_defaults_and_clamp(self):
        self.assertEqual(L.load_settings(), L.DEFAULTS)
        L.save_settings({"model": "x", "temperature": 9, "topp": 0.5, "tokens": 5, "memory": "many"})
        s = L.load_settings()
        self.assertEqual((s["model"], s["temperature"], s["topp"], s["tokens"], s["memory"]), ("x", 1.5, 0.5, 16, 60))

    def test_broken_file(self):
        open(L.SETTINGS, "w").write("{nonsense")
        self.assertEqual(L.load_settings(), L.DEFAULTS)


class Models(unittest.TestCase):
    def test_catalogue(self):
        ms = {m["id"]: m for m in L.load_models()}
        self.assertIn("stories15M", ms)
        for m in ms.values():
            self.assertTrue(m["file"].endswith(".bin"))
            self.assertTrue(m.get("convert") or (m.get("url", "").startswith("https://") and len(m.get("sha256", "")) == 64), m["id"])
        self.assertFalse(L.installed(ms["stories15M"]))
        self.assertIn("not downloaded", L.describe(ms["stories15M"]))

    def test_user_entries_replace(self):
        os.makedirs(L.DIR, exist_ok=True)
        json.dump([{"id": "stories15M", "name": "mine", "file": "m.bin", "size": 3}, {"id": "own", "name": "own", "file": "o.bin"}], open(os.path.join(L.DIR, "models.json"), "w"))
        ms = {m["id"]: m for m in L.load_models()}
        self.assertEqual(ms["stories15M"]["name"], "mine")
        self.assertIn("own", ms)
        os.remove(os.path.join(L.DIR, "models.json"))

    def test_installed_needs_the_right_size(self):
        m = {"id": "t", "file": "t.bin", "size": 4}
        os.makedirs(L.MODELS_DIR, exist_ok=True)
        open(L.model_path(m), "wb").write(b"abc")
        self.assertFalse(L.installed(m))
        open(L.model_path(m), "wb").write(b"abcd")
        self.assertTrue(L.installed(m))
        L.delete_model(m)
        self.assertFalse(L.installed(m))

    def test_fits(self):
        self.assertTrue(L.fits({"size": 100 * 1024 * 1024}))
        self.assertFalse(L.fits({"size": 167 * 1024 * 1024}))


class Prompt(unittest.TestCase):
    def test_tail_of_the_story(self):
        self.assertEqual(L.build_prompt("", " A robot ", 60), "A robot")
        self.assertEqual(L.build_prompt("one two three four", "five", 2), "three four five")
        self.assertEqual(L.build_prompt("one two", "three", 0), "three")

    def test_command(self):
        m = {"id": "t", "file": "t.bin", "tokenizer": "tokenizer.bin"}
        c = L.engine_command(m, dict(L.DEFAULTS, tokens=100, temperature=0.5, topp=1.0), "Once upon a time")
        self.assertEqual(c[c.index("-t") + 1], "0.5")
        self.assertEqual(c[c.index("-p") + 1], "1")
        self.assertEqual(c[-2:], ["-i", "Once upon a time"])
        self.assertTrue(106 <= int(c[c.index("-n") + 1]) <= 120)


class Stream(unittest.TestCase):
    def test_echo_is_dropped_whatever_the_case_and_cuts(self):
        s = L.Streamer("a robot  who")
        out = ""
        for b in [b"A Rob", b"ot W", b"ho lived in \xc4", b"\x8d"]:
            out += s.feed(b)
        out += s.feed(b"", True)
        self.assertEqual(out, " lived in č")

    def test_no_echo_shows_everything(self):
        s = L.Streamer("hello")
        self.assertEqual(s.feed(b"xyz and more", True), "xyz and more")

    def test_empty_prompt(self):
        self.assertEqual(L.Streamer("").feed(b"text"), "text")


class Engine(unittest.TestCase):
    def test_generation(self):
        m = {"id": "t", "file": "t.bin"}
        g = L.Generation(L.engine_command(m, L.DEFAULTS, "a robot"), "a robot")
        self.assertEqual(run(g), "  and the robot sáng a song.")
        self.assertEqual(g.speed, 3.25)
        self.assertIsNone(g.error)

    def test_stop(self):
        open(L.ENGINE + ".slow", "w").write("#!%s\nimport time\ntime.sleep(30)\n" % sys.executable)
        os.chmod(L.ENGINE + ".slow", 0o755)
        g = L.Generation([L.ENGINE + ".slow"], "x")
        g.stop()
        run(g)
        self.assertTrue(g.stopped)
        self.assertIsNone(g.error)

    def test_failure_reports_the_last_line(self):
        open(L.ENGINE + ".bad", "w").write("#!%s\nimport sys\nsys.stderr.write('warning\\nCould not open model\\n'); sys.exit(1)\n" % sys.executable)
        os.chmod(L.ENGINE + ".bad", 0o755)
        g = L.Generation([L.ENGINE + ".bad"], "x")
        run(g)
        self.assertEqual(g.error, "Could not open model")


def drive(job, limit=30):
    end = time.time() + limit
    seen = []
    while time.time() < end:
        done, frac, text, err = job.poll()
        seen.append(frac)
        if done:
            return frac, err, seen
        time.sleep(0.01)
    raise AssertionError("the job did not finish")


class Download(unittest.TestCase):
    def setUp(self):
        self.src = os.path.join(TMP, "src")
        os.makedirs(self.src, exist_ok=True)

    def entry(self, data, sha=None, name="d.bin"):
        p = os.path.join(self.src, name)
        open(p, "wb").write(data)
        return {"id": name, "file": name, "size": len(data), "sha256": sha or hashlib.sha256(data).hexdigest(), "url": "file://" + p}

    def test_download(self):
        m = self.entry(os.urandom(300000))
        frac, err, seen = drive(L.Job(m))
        self.assertIsNone(err)
        self.assertEqual(frac, 1.0)
        self.assertEqual(seen, sorted(seen))
        self.assertTrue(L.installed(m))
        L.delete_model(m)

    def test_wrong_checksum_removes_the_file(self):
        m = self.entry(b"x" * 1000, sha="0" * 64, name="bad.bin")
        frac, err, _ = drive(L.Job(m))
        self.assertIn("checksum", err)
        self.assertFalse(os.path.exists(L.model_path(m)))

    def test_missing_file(self):
        m = self.entry(b"x" * 10, name="gone.bin")
        os.remove(os.path.join(self.src, "gone.bin"))
        frac, err, _ = drive(L.Job(m))
        self.assertTrue(err)

    def test_cancel(self):
        m = self.entry(os.urandom(1000), name="c.bin")
        j = L.Job(m)
        j.poll()
        j.cancel()
        self.assertTrue(j.poll()[0])
        self.assertFalse(os.path.exists(L.model_path(m)))

    def test_convert(self):
        """A tiny Llama checkpoint (dim 8, 2 heads / 1 kv head, hidden 16, 1 layer, vocab 10) goes through the real converter."""
        dim, hid, voc, hs = 8, 16, 10, 4
        t = {"model.embed_tokens.weight": ((voc, dim), range(voc * dim)),
             "model.layers.0.input_layernorm.weight": ((dim,), [1.0] * dim),
             "model.layers.0.self_attn.q_proj.weight": ((dim, dim), range(dim * dim)),
             "model.layers.0.self_attn.k_proj.weight": ((hs, dim), range(hs * dim)),
             "model.layers.0.self_attn.v_proj.weight": ((hs, dim), [0.5] * (hs * dim)),
             "model.layers.0.self_attn.o_proj.weight": ((dim, dim), [0.25] * (dim * dim)),
             "model.layers.0.post_attention_layernorm.weight": ((dim,), [1.0] * dim),
             "model.layers.0.mlp.gate_proj.weight": ((hid, dim), [0.1] * (hid * dim)),
             "model.layers.0.mlp.down_proj.weight": ((dim, hid), [0.2] * (dim * hid)),
             "model.layers.0.mlp.up_proj.weight": ((hid, dim), [0.3] * (hid * dim)),
             "model.norm.weight": ((dim,), [1.0] * dim),
             "lm_head.weight": ((voc, dim), [0.4] * (voc * dim))}
        make_safetensors(os.path.join(self.src, "model.safetensors"), t)
        json.dump({"hidden_size": dim, "intermediate_size": hid, "num_hidden_layers": 1, "num_attention_heads": 2, "num_key_value_heads": 1,
                   "vocab_size": voc, "max_position_embeddings": 64, "hidden_act": "silu"}, open(os.path.join(self.src, "config.json"), "w"))
        files = []
        for n in ("config.json", "model.safetensors"):
            d = open(os.path.join(self.src, n), "rb").read()
            files.append({"name": n, "url": "file://" + os.path.join(self.src, n), "size": len(d), "sha256": hashlib.sha256(d).hexdigest()})
        m = {"id": "tiny", "file": "tiny.bin", "convert": {"files": files}}
        frac, err, _ = drive(L.Job(m))
        self.assertIsNone(err)
        data = open(L.model_path(m), "rb").read()
        head = struct.unpack("<7i", data[:28])
        self.assertEqual(head, (dim, hid, 1, 2, 1, -voc, 64))                     # negative vocab: the classifier is not shared
        floats = array.array("f")
        floats.frombytes(data[28:])
        n_emb = voc * dim
        wq = floats[n_emb + dim:n_emb + dim + dim * dim]
        # HF row order (half, pair) -> llama2.c (pair interleaved): head 0 has rows 0..3 -> 0, 2, 1, 3
        self.assertEqual([wq[r * dim] // dim for r in range(4)], [0, 2, 1, 3])
        expect = n_emb + dim + dim * dim + hs * dim * 2 + dim * dim + dim + hid * dim * 2 + dim * hid + dim + 2 * (64 * hs // 2) + voc * dim
        self.assertEqual(len(floats), expect)
        self.assertFalse(os.path.exists(os.path.join(L.MODELS_DIR, ".work", "tiny")))


if __name__ == "__main__":
    unittest.main(verbosity=1)
