"""Tests of notpipe_core: a fake Invidious server on localhost, real curl, a fake ffmpeg and a fake player. No network, no GUI."""
import http.server, json, os, shutil, sys, tempfile, threading, time, unittest

HERE = os.path.dirname(os.path.abspath(__file__))
TMP = tempfile.mkdtemp(prefix="notpipe-test-")
os.environ.update(NOTPIPE_DIR=os.path.join(TMP, "cfg"), NOTPIPE_CACHE=os.path.join(TMP, "cache"), NOTPIPE_SAVE=os.path.join(TMP, "save"),
                  NOTPIPE_FFMPEG=os.path.join(HERE, "fake-ffmpeg.sh"), NOTPIPE_PLAYER=os.path.join(HERE, "fake-player.sh"), HOME=TMP)
sys.path.insert(0, os.path.join(HERE, ".."))
import notpipe_core as N

VIDEO_BYTES = bytes(range(256)) * 400          # 102400 bytes
AUDIO_BYTES = bytes(reversed(range(256))) * 300  # 76800 bytes


def fmt(itag, typ, label=None, size=0):
    d = {"itag": str(itag), "type": typ, "url": "{BASE}/files/%d.mp4" % itag, "clen": str(size)}
    if label:
        d["qualityLabel"] = label
    return d


FORMATS = [fmt(160, 'video/mp4; codecs="avc1.4D400C"', "144p", 5000), fmt(133, 'video/mp4; codecs="avc1.4D4015"', "240p", len(VIDEO_BYTES)),
           fmt(134, 'video/mp4; codecs="avc1.4D401E"', "360p", 9000), fmt(243, 'video/webm; codecs="vp9"', "360p", 9000),
           fmt(396, 'video/mp4; codecs="av01.0.01M.08"', "360p", 9000), fmt(298, 'video/mp4; codecs="avc1.4D401F"', "720p60", 9000),
           fmt(140, 'audio/mp4; codecs="mp4a.40.2"', None, len(AUDIO_BYTES)), fmt(139, 'audio/mp4; codecs="mp4a.40.5"', None, 3000),
           fmt(251, 'audio/webm; codecs="opus"', None, 4000)]


class Handler(http.server.BaseHTTPRequestHandler):
    mode = "ok"
    calls = 0
    ranges = []

    def log_message(self, *a):
        pass

    def _send(self, code, body, ctype="application/json", extra=None):
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        for k, v in (extra or {}).items():
            self.send_header(k, v)
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        type(self).calls += 1
        base = "http://127.0.0.1:%d" % self.server.server_port
        path = self.path
        if self.mode == "html" and path.startswith("/api"):
            return self._send(200, b"<html><title>Verifying your browser</title></html>", "text/html")
        if self.mode == "down":
            return self._send(503, b"busy")
        if self.mode == "forbid" and path.startswith("/files/"):
            return self._send(403, b"forbidden")
        if path.startswith("/vi/"):
            if "NOPIC" in path:
                return self._send(404, b"no")
            return self._send(200, b"\xff\xd8\xff" + b"jpeg" * 100, "image/jpeg")
        if path.startswith("/api/v1/search"):
            items = [{"type": "video", "videoId": "AAAAAAAAAAA", "title": "First video", "author": "Alice", "lengthSeconds": 466, "viewCount": 12345, "publishedText": "1 year ago",
                      "videoThumbnails": [{"quality": "maxres", "url": "/vi/AAAAAAAAAAA/maxres.jpg"}, {"quality": "medium", "url": "/vi/AAAAAAAAAAA/mqdefault.jpg"}]},
                     {"type": "channel", "author": "A channel"},
                     {"type": "video", "videoId": "BBBBBBBBBBB", "title": "Live now", "author": "Bob", "lengthSeconds": 0, "liveNow": True},
                     {"type": "video", "videoId": "bad id", "title": "Broken id"},
                     {"type": "video", "videoId": "CCCCCCCCCCC", "title": "Second", "author": "Carol", "lengthSeconds": 61, "viewCount": 7,
                      "videoThumbnails": [{"quality": "default", "url": "%s/vi/NOPIC/default.jpg" % base}]}]
            return self._send(200, json.dumps(items).encode())
        if path.startswith("/api/v1/videos/"):
            if path.endswith("/NNNNNNNNNNN"):
                return self._send(404, json.dumps({"error": "Video unavailable"}).encode())
            if path.endswith("/LLLLLLLLLLL"):
                return self._send(200, json.dumps({"title": "Live", "formats": [], "adaptiveFormats": []}).encode())
            fm = json.loads(json.dumps(FORMATS).replace("{BASE}", base))
            return self._send(200, json.dumps({"title": "A/B: test? video", "author": "Alice", "lengthSeconds": 466, "adaptiveFormats": fm}).encode())
        if path == "/instances.json":
            return self._send(200, json.dumps([["a.example", {"type": "https", "api": True, "uri": base}], ["b.example", {"type": "https", "api": False, "uri": "https://b.example"}],
                                               ["c.example", {"type": "onion", "api": True, "uri": "http://c.onion"}]]).encode())
        if path.startswith("/files/"):
            data = VIDEO_BYTES if path.endswith("133.mp4") else AUDIO_BYTES if path.endswith("140.mp4") else b"x" * 3000
            if path.endswith("404.mp4"):
                return self._send(404, b"gone")
            rng = self.headers.get("Range")
            if rng and rng.startswith("bytes="):
                a, _, b = rng[6:].partition("-")
                start = int(a)
                end = min(int(b), len(data) - 1) if b else len(data) - 1
                type(self).ranges.append((start, end))
                return self._send(206, data[start:end + 1], "video/mp4", {"Content-Range": "bytes %d-%d/%d" % (start, end, len(data))})
            return self._send(200, data, "video/mp4")
        self._send(404, b"not found")


def serve(mode="ok"):
    cls = type("H", (Handler,), {"mode": mode})
    srv = http.server.ThreadingHTTPServer(("127.0.0.1", 0), cls)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    return srv, "http://127.0.0.1:%d" % srv.server_port


def run_job(job, limit=30):
    t0 = time.time()
    while True:
        r = job.poll()
        if r[0]:
            return r
        if time.time() - t0 > limit:
            raise AssertionError("the job takes too long")
        time.sleep(0.02)


class Base(unittest.TestCase):
    def setUp(self):
        N._last_good = None
        N.bundled_instances = lambda: []
        for d in ("cfg", "cache", "save"):
            shutil.rmtree(os.path.join(TMP, d), ignore_errors=True)
        self.servers = []

    def tearDown(self):
        for s in self.servers:
            s.shutdown()

    def server(self, mode="ok"):
        s, url = serve(mode)
        self.servers.append(s)
        return url


class Formatting(unittest.TestCase):
    def test_helpers(self):
        self.assertEqual(N.fmt_duration(466), "7:46")
        self.assertEqual(N.fmt_duration(3725), "1:02:05")
        self.assertEqual(N.fmt_duration(0), "0:00")
        self.assertEqual(N.fmt_size(3 * 1048576), "3.0 MB")
        self.assertEqual(N.fmt_size(2048), "2 kB")
        self.assertEqual((N.fmt_count(12345), N.fmt_count(2500000), N.fmt_count(7)), ("12k", "2.5M", "7"))

    def test_safe_name_for_a_fat_card(self):
        self.assertEqual(N.safe_name('A/B: "test"? <x>|y*'), "A_B_ _test__ _x__y_")
        self.assertEqual(N.safe_name("..."), "video")
        self.assertLessEqual(len(N.safe_name("x" * 300)), 80)

    def test_settings(self):
        self.assertEqual(N.load_settings(), N.DEFAULTS)
        os.makedirs(N.DIR, exist_ok=True)
        json.dump({"quality": 360, "audio": 139, "cache_mb": 99999999, "junk": 1}, open(N.SETTINGS, "w"))
        s = N.load_settings()
        self.assertEqual((s["quality"], s["audio"], s["cache_mb"]), (360, 139, 4000))
        json.dump({"quality": 1080, "audio": "x"}, open(N.SETTINGS, "w"))
        self.assertEqual(N.load_settings(), N.DEFAULTS)                 # values that are not choices are ignored
        N.save_settings({"quality": 144, "audio": 140, "cache_mb": 100})
        self.assertEqual(N.load_settings()["quality"], 144)


class Instances(Base):
    def test_search_parses_and_skips(self):
        base = self.server()
        N.bundled_instances = lambda: [base]
        r = N.search("maemo n900")
        self.assertEqual([v["id"] for v in r], ["AAAAAAAAAAA", "CCCCCCCCCCC"])      # channel, live stream and a bad id are skipped
        self.assertEqual((r[0]["title"], r[0]["author"], r[0]["length"], r[0]["views"]), ("First video", "Alice", 466, 12345))

    def test_a_browser_check_page_is_skipped_and_the_next_instance_is_used(self):
        bad, good = self.server("html"), self.server()
        N.bundled_instances = lambda: [bad, good]
        self.assertEqual(len(N.search("x")), 2)
        self.assertEqual(N.instances()[0], good)                                    # the one that worked is tried first from now on

    def test_all_instances_down_gives_a_readable_error(self):
        a, b = self.server("down"), self.server("html")
        N.bundled_instances = lambda: [a, b]
        with self.assertRaises(N.ApiError) as cm:
            N.search("x")
        self.assertIn("no instance answered", str(cm.exception))
        self.assertIn("browser check", str(cm.exception))

    def test_no_instances(self):
        with self.assertRaises(N.ApiError) as cm:
            N.search("x")
        self.assertIn("empty", str(cm.exception))

    def test_unreachable_instance(self):
        N.bundled_instances = lambda: ["http://127.0.0.1:9"]                         # nothing listens there
        with self.assertRaises(N.ApiError):
            N.search("x")

    def test_refresh_keeps_https_instances_with_api(self):
        base = self.server()
        N.INSTANCE_SOURCE = base + "/instances.json"
        self.assertTrue(N.instance_list_is_old())
        self.assertEqual(N.refresh_instances(), [base])
        self.assertFalse(N.instance_list_is_old())
        self.assertEqual(N.instances(), [base])

    def test_query_is_url_encoded(self):
        base = self.server()
        N.bundled_instances = lambda: [base]
        self.assertEqual(len(N.search("a b&c=d/é")), 2)


class Streams(Base):
    def info(self):
        base = self.server()
        N.bundled_instances = lambda: [base]
        return N.video_info("AAAAAAAAAAA")

    def test_pick_by_quality(self):
        info = self.info()
        for quality, itag in ((144, 160), (240, 133), (360, 134), (480, 134), (720, 298)):
            v, a = N.pick_streams(info, quality, 140)
            self.assertEqual(v["itag"], itag, quality)
            self.assertEqual(a["itag"], 140)
        v, a = N.pick_streams(info, 100, 139)                                          # below all: the lowest one
        self.assertEqual((v["itag"], a["itag"]), (160, 139))

    def test_vp9_and_av1_are_never_picked(self):
        info = self.info()
        self.assertTrue(all(f["codec"].startswith("avc1") for f in [N.pick_streams(info, q)[0] for q in (144, 240, 360)]))

    def test_no_h264_or_no_audio(self):
        info = self.info()
        with self.assertRaises(N.ApiError):
            N.pick_streams(dict(info, formats=[f for f in info["formats"] if not f["codec"].startswith("avc1")]))
        with self.assertRaises(N.ApiError):
            N.pick_streams(dict(info, formats=[f for f in info["formats"] if f["kind"] == "video"]))

    def test_audio_falls_back_to_any_aac(self):
        info = self.info()
        info["formats"] = [f for f in info["formats"] if f["itag"] != 139]
        self.assertEqual(N.pick_streams(info, 240, 139)[1]["itag"], 140)

    def test_errors_of_the_api(self):
        base = self.server()
        N.bundled_instances = lambda: [base]
        with self.assertRaises(N.ApiError) as cm:
            N.video_info("NNNNNNNNNNN")
        self.assertIn("unavailable", str(cm.exception).lower())
        with self.assertRaises(N.ApiError):
            N.video_info("LLLLLLLLLLL")                                               # no streams: a live stream
        with self.assertRaises(N.ApiError):
            N.video_info("../../etc/passwd")                                         # not an id: never sent


class Downloads(Base):
    def prepare(self):
        base = self.server()
        N.bundled_instances = lambda: [base]
        info = N.video_info("AAAAAAAAAAA")
        return N.pick_streams(info, 240, 140)

    def test_download_two_files(self):
        v, a = self.prepare()
        job = N.Job("AAAAAAAAAAA", v, a)
        done, frac, text, err = run_job(job)
        self.assertIsNone(err)
        self.assertEqual(frac, 1.0)
        self.assertEqual(open(job.vpath, "rb").read(), VIDEO_BYTES)
        self.assertEqual(open(job.apath, "rb").read(), AUDIO_BYTES)
        self.assertEqual([n for n in os.listdir(N.CACHE) if n.endswith(".part")], [])

    def test_a_stream_is_downloaded_in_pieces(self):
        v, a = self.prepare()
        old, N.CHUNK = N.CHUNK, 30000
        try:
            del Handler.ranges[:]
            job = N.Job("AAAAAAAAAAA", v, a)
            self.assertIsNone(run_job(job)[3])
        finally:
            N.CHUNK = old
        self.assertEqual(open(job.vpath, "rb").read(), VIDEO_BYTES)
        self.assertEqual(open(job.apath, "rb").read(), AUDIO_BYTES)
        self.assertGreaterEqual(len(Handler.ranges), 3 + 3)                    # 102400 B in pieces of 30000 = 4, 76800 B = 3
        self.assertEqual(Handler.ranges[0], (0, 29999))

    def test_a_server_that_ignores_the_range_is_an_error(self):
        v, a = self.prepare()
        v = dict(v, url=v["url"].replace("133.mp4", "999.mp4"))               # this one answers 200 with 3000 bytes whatever is asked
        v["size"] = 5000
        err = run_job(N.Job("AAAAAAAAAAA", v, a))[3]
        self.assertTrue(err)

    def test_progress_goes_up(self):
        v, a = self.prepare()
        job = N.Job("AAAAAAAAAAA", v, a)
        seen = []
        t0 = time.time()
        while True:
            r = job.poll()
            seen.append(r[1])
            if r[0] or time.time() - t0 > 20:
                break
            time.sleep(0.005)
        self.assertEqual(seen, sorted(seen))
        self.assertEqual(seen[-1], 1.0)

    def test_files_in_the_cache_are_not_downloaded_again(self):
        v, a = self.prepare()
        run_job(N.Job("AAAAAAAAAAA", v, a))
        calls = Handler.calls
        job = N.Job("AAAAAAAAAAA", v, a)
        self.assertEqual(job.steps, [])
        self.assertTrue(run_job(job)[0])
        self.assertEqual(Handler.calls, calls)

    def test_a_partial_file_is_resumed(self):
        v, a = self.prepare()
        os.makedirs(N.CACHE, exist_ok=True)
        open(N.stream_path("AAAAAAAAAAA", v) + ".part", "wb").write(VIDEO_BYTES[:50000])       # an earlier, interrupted download
        job = N.Job("AAAAAAAAAAA", v, a)
        self.assertIsNone(run_job(job)[3])
        self.assertEqual(open(job.vpath, "rb").read(), VIDEO_BYTES)

    def test_a_wrong_size_is_an_error(self):
        v, a = self.prepare()
        v = dict(v, size=len(VIDEO_BYTES) + 5)
        err = run_job(N.Job("AAAAAAAAAAA", v, a))[3]
        self.assertIn("incomplete", err)

    def test_http_error(self):
        v, a = self.prepare()
        v = dict(v, url=v["url"].replace("133.mp4", "404.mp4"))
        err = run_job(N.Job("AAAAAAAAAAA", v, a))[3]
        self.assertTrue(err)

    def test_cancel_removes_the_part_file(self):
        v, a = self.prepare()
        job = N.Job("AAAAAAAAAAA", v, a)
        job.poll()
        job.cancel()
        self.assertTrue(job.poll()[0])
        self.assertEqual([n for n in os.listdir(N.CACHE) if n.endswith(".part")], [])

    def test_save_joins_the_files_into_one(self):
        v, a = self.prepare()
        out = os.path.join(N.SAVE_DIR, "x.mp4")
        job = N.Job("AAAAAAAAAAA", v, a, out)
        self.assertIsNone(run_job(job)[3])
        self.assertEqual(open(out, "rb").read(), VIDEO_BYTES + AUDIO_BYTES)             # the fake ffmpeg concatenates
        self.assertFalse(os.path.exists(job.vpath) or os.path.exists(job.apath))        # the two streams are removed once they are joined
        self.assertEqual([n for n in os.listdir(N.SAVE_DIR) if "part" in n], [])

    def test_a_failing_ffmpeg_is_reported(self):
        v, a = self.prepare()
        err = run_job(N.Job("AAAAAAAAAAA", v, a, os.path.join(N.SAVE_DIR, "fail.mp4")))[3]
        self.assertIn("fake ffmpeg", err)
        self.assertFalse(os.path.exists(os.path.join(N.SAVE_DIR, "fail.mp4")))

    def test_remux_command_copies_without_reencoding(self):
        cmd = N.remux_command("v.mp4", "a.mp4", "out.mp4")
        self.assertEqual(cmd[-1], "out.mp4")
        self.assertIn("copy", cmd)
        self.assertEqual(cmd[cmd.index("-c") + 1], "copy")


class Thumbnails(Base):
    def results(self):
        base = self.server()
        N.bundled_instances = lambda: [base]
        return base, N.search("x")

    def test_search_gives_the_medium_thumbnail_and_resolves_a_relative_url(self):
        base, r = self.results()
        self.assertEqual(r[0]["thumb"], base + "/vi/AAAAAAAAAAA/mqdefault.jpg")          # "medium" is preferred, a relative url gets the instance
        self.assertTrue(r[1]["thumb"].endswith("/vi/NOPIC/default.jpg"))                  # "default" when there is no medium one

    def test_loader_downloads_and_skips_failures(self):
        base, r = self.results()
        loader = N.ThumbLoader(r)
        got = []
        for _ in range(200):
            got += loader.poll()
            if got:
                time.sleep(0.2)
                got += loader.poll()
                break
            time.sleep(0.05)
        self.assertEqual(got, ["AAAAAAAAAAA"])                                            # the second picture is a 404: skipped, no crash
        self.assertTrue(os.path.getsize(N.thumb_path("AAAAAAAAAAA")) > 100)
        self.assertFalse(os.path.exists(N.thumb_path("CCCCCCCCCCC")))
        self.assertEqual([n for n in os.listdir(N.thumb_dir()) if n.endswith(".part")], [])

    def test_a_loaded_thumbnail_is_not_downloaded_again(self):
        base, r = self.results()
        os.makedirs(N.thumb_dir(), exist_ok=True)
        open(N.thumb_path("AAAAAAAAAAA"), "wb").write(b"x" * 500)
        calls = Handler.calls
        loader = N.ThumbLoader(r[:1])
        for _ in range(100):
            if loader.poll():
                break
            time.sleep(0.02)
        self.assertEqual(Handler.calls, calls)

    def test_clear_cache_removes_thumbnails_too(self):
        os.makedirs(N.thumb_dir(), exist_ok=True)
        open(N.thumb_path("AAAAAAAAAAA"), "wb").write(b"x" * 500)
        N.clear_cache()
        self.assertEqual(N.thumb_files(), [])

    def test_the_thumbnail_folder_is_not_counted_as_a_cache_file(self):
        os.makedirs(N.thumb_dir(), exist_ok=True)
        self.assertEqual(N.cache_files(), [])


class LastResults(Base):
    def test_round_trip(self):
        r = [{"id": "AAAAAAAAAAA", "title": "T", "author": "A", "length": 5, "views": 1, "published": "", "thumb": ""}]
        N.save_last("old phones", r, 2)
        self.assertEqual(N.load_last(), ("old phones", r, 2))

    def test_nothing_or_a_damaged_file(self):
        self.assertEqual(N.load_last(), ("", [], 0))
        os.makedirs(N.DIR, exist_ok=True)
        open(N.LAST, "w").write("{not json")
        self.assertEqual(N.load_last(), ("", [], 0))
        json.dump({"query": "x", "results": [{"id": "bad id"}, {"id": "AAAAAAAAAAA"}], "page": 1}, open(N.LAST, "w"))
        self.assertEqual([x["id"] for x in N.load_last()[1]], ["AAAAAAAAAAA"])


class Retry(Base):
    def test_a_403_makes_the_next_try_use_another_instance(self):
        bad, good = self.server("forbid"), self.server()
        N.bundled_instances = lambda: [bad, good]
        pb = N.Playback("AAAAAAAAAAA", dict(N.DEFAULTS))
        r = run_job(pb)
        self.assertIsNone(r[3])
        self.assertIn(bad, pb.bad)
        self.assertEqual(open(pb.vpath, "rb").read(), VIDEO_BYTES)

    def test_every_instance_refuses(self):
        a, b = self.server("forbid"), self.server("forbid")
        N.bundled_instances = lambda: [a, b]
        err = run_job(N.Playback("AAAAAAAAAAA", dict(N.DEFAULTS)))[3]
        self.assertIn("every instance", err)

    def test_skip_leaves_out_instances(self):
        a, b = self.server(), self.server()
        N.bundled_instances = lambda: [a, b]
        N.video_info("AAAAAAAAAAA", skip=(a,))
        self.assertEqual(N.current_instance(), b)
        with self.assertRaises(N.ApiError):
            N.video_info("AAAAAAAAAAA", skip=(a, b))


class Saved(Base):
    def put(self, name, data=b"x" * 10):
        os.makedirs(N.SAVE_DIR, exist_ok=True)
        open(os.path.join(N.SAVE_DIR, name), "wb").write(data)

    def test_saved_file_is_found_by_the_id_in_its_name(self):
        self.assertIsNone(N.saved_file("AAAAAAAAAAA"))
        self.put("Some title [AAAAAAAAAAA].mp4")
        self.put("Other [BBBBBBBBBBB].mp4")
        self.put("not ours.mp4")
        self.assertTrue(N.saved_file("AAAAAAAAAAA").endswith("Some title [AAAAAAAAAAA].mp4"))
        self.assertEqual(N.saved_ids(), {"AAAAAAAAAAA", "BBBBBBBBBBB"})

    def test_watching_a_saved_video_plays_the_file_without_the_network(self):
        self.put("Some title [AAAAAAAAAAA].mp4", b"video")
        calls = Handler.calls
        pb = N.Playback("AAAAAAAAAAA", dict(N.DEFAULTS))
        r = pb.poll()
        self.assertEqual((r[0], r[3]), (True, None))
        self.assertEqual(pb.vpath, pb.apath)
        self.assertTrue(pb.vpath.endswith("[AAAAAAAAAAA].mp4"))
        self.assertEqual(Handler.calls, calls)                                           # nothing was asked from an instance

    def test_downloading_ignores_the_saved_file_check_and_does_not_play(self):
        base = self.server()
        N.bundled_instances = lambda: [base]
        pb = N.Playback("AAAAAAAAAAA", dict(N.DEFAULTS), save=True)
        self.assertIsNone(run_job(pb)[3])
        self.assertTrue(os.path.exists(pb.saved_to))
        self.assertEqual(N.saved_ids(), {"AAAAAAAAAAA"})
        self.assertEqual(os.listdir(N.CACHE), [])                                        # the cache keeps nothing of it

    def test_the_cache_is_a_visible_folder_inside_the_videos_folder(self):
        self.assertEqual(os.path.basename(N.thumb_dir()), "thumbs")
        self.assertEqual(os.path.dirname(N.thumb_dir()), N.CACHE)

    def test_the_old_cache_moves_to_the_new_place(self):
        old = os.path.join(TMP, "oldplace")
        os.makedirs(old)
        open(os.path.join(old, "x"), "w").write("1")
        saved = (N.OLD_CACHE, N.CACHE, N.SAVE_DIR)
        try:
            N.OLD_CACHE, N.SAVE_DIR = old, os.path.join(TMP, "vids")
            N.CACHE = os.path.join(N.SAVE_DIR, "NotPipe cache")
            self.assertTrue(N.migrate_old_cache())
            self.assertTrue(os.path.exists(os.path.join(N.CACHE, "x")))
            self.assertFalse(N.migrate_old_cache())                                      # once
        finally:
            N.OLD_CACHE, N.CACHE, N.SAVE_DIR = saved


class Cache(Base):
    def fill(self, names_sizes):
        os.makedirs(N.CACHE, exist_ok=True)
        now = time.time()
        for i, (name, size) in enumerate(names_sizes):
            p = os.path.join(N.CACHE, name)
            open(p, "wb").write(b"x" * size)
            os.utime(p, (now - 1000 + i, now - 1000 + i))                               # a later one is newer

    def test_prune_removes_the_oldest_first(self):
        self.fill([("a", 100), ("b", 100), ("c", 100)])
        N.prune_cache(250)
        self.assertEqual(sorted(os.listdir(N.CACHE)), ["b", "c"])

    def test_prune_keeps_the_wanted_files(self):
        self.fill([("a", 100), ("b", 100), ("c", 100)])
        N.prune_cache(150, keep=(os.path.join(N.CACHE, "a"),))
        self.assertEqual(sorted(os.listdir(N.CACHE)), ["a"])

    def test_size_and_clear(self):
        self.fill([("a", 100), ("b", 50)])
        self.assertEqual(N.cache_size(), 150)
        self.assertEqual(N.clear_cache(), 2)
        self.assertEqual(N.cache_size(), 0)


class Flow(Base):
    def test_playback_then_player(self):
        base = self.server()
        N.bundled_instances = lambda: [base]
        pb = N.Playback("AAAAAAAAAAA", dict(N.DEFAULTS))
        r = run_job(pb)
        self.assertIsNone(r[3])
        self.assertEqual(os.path.basename(pb.vpath), "AAAAAAAAAAA-133.mp4")
        self.assertEqual(os.path.basename(pb.apath), "AAAAAAAAAAA-140.mp4")
        pl = N.Player(pb.vpath, pb.apath)
        res = None
        for _ in range(100):
            res = pl.poll()
            if res:
                break
            time.sleep(0.02)
        self.assertEqual(res[0], 0)
        self.assertIn("playing AAAAAAAAAAA-133.mp4", res[1])

    def test_cached_video_plays_without_the_network(self):
        base = self.server()
        N.bundled_instances = lambda: [base]
        pb = N.Playback("AAAAAAAAAAA", dict(N.DEFAULTS))
        self.assertIsNone(run_job(pb)[3])
        self.assertTrue(os.path.exists(N.meta_path("AAAAAAAAAAA")))
        N.bundled_instances = lambda: []                                # no instance at all: still plays
        real = N.Task
        N.Task = lambda *a: self.fail("a call was made")                # and no call is made
        try:
            pb2 = N.Playback("AAAAAAAAAAA", dict(N.DEFAULTS))
            r = pb2.poll()
        finally:
            N.Task = real
        self.assertTrue(r[0] and r[3] is None)
        self.assertEqual(os.path.basename(pb2.vpath), "AAAAAAAAAAA-133.mp4")

    def test_list_of_cached_videos(self):
        base = self.server()
        N.bundled_instances = lambda: [base]
        self.assertEqual(N.cached_videos(), [])
        self.assertIsNone(run_job(N.Playback("AAAAAAAAAAA", dict(N.DEFAULTS)))[3])
        lst = N.cached_videos()
        self.assertEqual([v["id"] for v in lst], ["AAAAAAAAAAA"])
        self.assertEqual(N.cached_ids(), {"AAAAAAAAAAA"})
        self.assertEqual(lst[0]["title"], "A/B: test? video")
        os.remove(N.stream_path("AAAAAAAAAAA", {"itag": 140}))          # an incomplete one is not listed
        self.assertEqual(N.cached_videos(), [])
        os.makedirs(N.SAVE_DIR, exist_ok=True)
        open(os.path.join(N.SAVE_DIR, "Some title [BBBBBBBBBBB].mp4"), "w").close()
        self.assertEqual([(v["id"], v["title"]) for v in N.cached_videos()], [("BBBBBBBBBBB", "Some title")])

    def test_playback_with_save(self):
        base = self.server()
        N.bundled_instances = lambda: [base]
        pb = N.Playback("AAAAAAAAAAA", dict(N.DEFAULTS), save=True)
        self.assertIsNone(run_job(pb)[3])
        self.assertTrue(pb.saved_to.endswith("A_B_ test_ video [AAAAAAAAAAA].mp4"))
        self.assertTrue(os.path.exists(pb.saved_to))

    def test_playback_error_of_the_api(self):
        base = self.server()
        N.bundled_instances = lambda: [base]
        self.assertIn("unavailable", run_job(N.Playback("NNNNNNNNNNN", dict(N.DEFAULTS)))[3].lower())

    def test_playback_cancel(self):
        base = self.server()
        N.bundled_instances = lambda: [base]
        pb = N.Playback("AAAAAAAAAAA", dict(N.DEFAULTS))
        pb.cancel()
        self.assertEqual(pb.poll()[3], "cancelled")

    def test_player_reports_a_failure(self):
        pl = N.Player("/nonexistent/v.mp4", "/nonexistent/a.mp4")
        res = None
        for _ in range(100):
            res = pl.poll()
            if res:
                break
            time.sleep(0.02)
        self.assertEqual(res[0], 3)
        self.assertIn("missing files", res[1])

    def test_task_reports_exceptions(self):
        def boom():
            raise ValueError("bug")
        t = N.Task(boom)
        for _ in range(100):
            if t.poll()[0]:
                break
            time.sleep(0.01)
        self.assertIn("ValueError", t.poll()[2])


if __name__ == "__main__":
    try:
        unittest.main()
    finally:
        shutil.rmtree(TMP, ignore_errors=True)
