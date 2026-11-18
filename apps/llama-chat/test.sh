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
# The windows were checked in the emulator (make hildon-run APP=llama-chat); see README.md.
summary
