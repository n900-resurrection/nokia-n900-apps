TEST_NAME=llama-chat
need_pkg llama-chat
ok in-path sh -c 'command -v llama-chat'
ok desktop-entry test -r /usr/share/applications/hildon/llama-chat.desktop
ok engine test -x /opt/llama2c/bin/llama2c
ok modules sh -c '/opt/python3/bin/python3 -c "import hildonlite; hildonlite.Scale, hildonlite.PannableArea, hildonlite.TextView, hildonlite.Dialog"'
contains logic-catalogue "stories15M" sh -c 'cd /opt/llama-chat && /opt/python3/bin/python3 -c "
import llama_chat as L
print([m[\"id\"] for m in L.load_models()])"'
contains generation "once upon a time" sh -c 'cd /opt/llama-chat && LLAMACHAT_DIR=/home/user/.llama-chat-test /opt/python3/bin/python3 -c "
import time, llama_chat as L
m = [x for x in L.load_models() if x[\"id\"] == \"stories260K\"][0]
s = dict(L.DEFAULTS, tokens=20, temperature=0.5)
p = \"Once upon a time\"
g = L.Generation(L.engine_command(m, s, p), p)
out = \"\"
while True:
    t, done = g.poll(); out += t
    if done: break
    time.sleep(0.05)
print(p.lower(), out.lower())"; r=$?; rm -rf /home/user/.llama-chat-test; exit $r'
ok converter sh -c '/opt/python3/bin/python3 /opt/llama-chat/st2llama2c.py --help >/dev/null'
# the models go to the memory card when it is mounted (the system partition is small); the free memory is read and the check works
contains models-folder "models-folder-ok" sh -c 'su user -c "cd /opt/llama-chat && /opt/python3/bin/python3 -c \"
import os, llama_chat as L
card = os.path.ismount(os.path.expanduser(\\\"~/MyDocs\\\"))
print(\\\"models-folder-ok\\\" if L.MODELS_DIR.endswith(\\\"MyDocs/llama2c\\\") == card else \\\"models-folder-bad\\\", L.MODELS_DIR)\""'
contains free-memory-is-read "free-memory-ok" sh -c 'cd /opt/llama-chat && /opt/python3/bin/python3 -c "
import llama_chat as L
f = L.ram_free_bytes()
print(\"free-memory-ok\" if f and f > 0 and L.missing_ram({\"size\": 10 ** 12}, free=f) > 0 and L.missing_ram({\"size\": 1}, free=10 ** 9) == 0 else \"free-memory-bad\")"'
# The windows were checked in the emulator (make hildon-run APP=llama-chat); see README.md.
summary
