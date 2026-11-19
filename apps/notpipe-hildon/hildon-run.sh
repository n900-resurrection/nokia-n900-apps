# Name: NotPipe (notpipe-hildon)
# Sourced by scripts/hildon-run.sh (INSIDE the Workshop) for: make hildon-run APP=notpipe-hildon. A fake Invidious server on localhost (static files), fictional videos, no network.
RUN_SCRIPT=/project/apps/notpipe-hildon/notpipe-hildon
DEMO=/tmp/notpipe-demo
rm -rf "$DEMO"
mkdir -p "$DEMO/cfg" "$DEMO/www/api/v1/videos" "$DEMO/cache" "$DEMO/save"
python3 -I - "$DEMO/www/api/v1/search" <<'PY'
import json, sys
items = [("Building a tiny robot from spare parts", "Workshop Notes", 1262, 48210, "2 years ago"),
         ("Old phones, new tricks", "Pocket Retro", 466, 12345, "1 year ago"),
         ("Why a small language model can tell stories", "Quiet Lab", 787, 9300, "8 months ago"),
         ("Maemo 5: a short tour", "Pocket Retro", 100, 2750, "3 years ago"),
         ("Soldering for beginners, part 2", "Workshop Notes", 2230, 150400, "5 years ago"),
         ("A walk through the old town (4K)", "Slow Travel", 3725, 1260000, "4 months ago"),
         ("Linux on a phone from 2009", "Quiet Lab", 612, 31800, "1 year ago"),
         ("Cooking soup in ten minutes", "Kitchen Table", 640, 560, "2 weeks ago"),
         ("Keyboards that click", "Pocket Retro", 905, 22100, "6 months ago"),
         ("The sound of a spinning disk", "Quiet Lab", 355, 4020, "1 month ago")]
out = [{"type": "video", "videoId": "DEMO%07d" % i, "title": t, "author": a, "lengthSeconds": l, "viewCount": v, "publishedText": p,
        "videoThumbnails": [{"quality": "medium", "url": "/vi/DEMO%07d/mqdefault.jpg" % i}]} for i, (t, a, l, v, p) in enumerate(items)]
json.dump(out, open(sys.argv[1], "w"))
import os, subprocess
colors = ["#3b6ea5", "#a5523b", "#4f8a4f", "#8a4f8a", "#b59b3a", "#3a9ba5", "#7a7a7a", "#a53b5e", "#5e3ba5", "#3ba56a"]
for i in range(len(items)):
    d = os.path.join(os.path.dirname(sys.argv[1]), "..", "..", "vi", "DEMO%07d" % i)
    os.makedirs(d, exist_ok=True)
    subprocess.run(["convert", "-size", "320x180", "gradient:" + colors[i % len(colors)] + "-#202020", os.path.join(d, "mqdefault.jpg")], check=False)
PY
(cd "$DEMO/www" && setsid python3 -m http.server 8765 --bind 127.0.0.1 >/dev/null 2>&1 &)
export PYTHONPATH=/project/apps/hildonlite${PYTHONPATH:+:$PYTHONPATH}      # the hildonlite of this repository (the one in the sysroot is the released version)
export NOTPIPE_DIR=$DEMO/cfg NOTPIPE_CACHE=$DEMO/cache NOTPIPE_SAVE=$DEMO/save NOTPIPE_INSTANCES=http://127.0.0.1:8765 NOTPIPE_INSTANCE_SOURCE=http://127.0.0.1:8765/none \
       NOTPIPE_CURL=curl NOTPIPE_PLAYER=/bin/true
sleep 1
# screenshots: put lines like "export NOTPIPE_DEMO_QUERY=robot NOTPIPE_OPEN=settings" into build/notpipe-env
[ -f /project/build/notpipe-env ] && . /project/build/notpipe-env
