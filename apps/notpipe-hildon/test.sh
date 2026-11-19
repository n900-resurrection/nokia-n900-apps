TEST_NAME=notpipe-hildon
need_pkg notpipe-hildon
need_pkg nplay
need_pkg ffmpeg
ok in-path sh -c 'command -v notpipe-hildon'
ok desktop-entry test -r /usr/share/applications/hildon/notpipe-hildon.desktop
ok modules sh -c '/opt/python3/bin/python3 -c "import hildonlite; hildonlite.Scale, hildonlite.PannableArea, hildonlite.PickerButton, hildonlite.Dialog"'
ok curl-tls13 sh -c 'curl -sI -m 20 https://api.invidious.io/ >/dev/null'
contains logic-instances "https://" sh -c 'cd /opt/notpipe-hildon && NOTPIPE_DIR=/home/user/.notpipe-test /opt/python3/bin/python3 -c "
import notpipe_core as N
print(N.instances())"'
# A real search on a public instance: the instances come and go, so an unreachable one is a skip, not a failure.
r=$(cd /opt/notpipe-hildon && NOTPIPE_DIR=/home/user/.notpipe-test /opt/python3/bin/python3 -c "
import notpipe_core as N
try:
    r = N.search('nokia n900')
    print('found', len(r))
except N.ApiError as e:
    print('unreachable', str(e)[:100])" 2>&1)
case "$r" in
    "found "*) ok live-search test "${r#found }" -gt 0;;
    *) skip live-search "$r";;
esac
rm -rf /home/user/.notpipe-test
# The windows were checked in the emulator (make hildon-run APP=notpipe-hildon); see README.md.
summary
