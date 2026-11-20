TEST_NAME=cmus
need_pkg cmus
ok in-path sh -c 'command -v cmus && command -v cmus-remote'
ok version sh -c 'cmus --version | head -1 | grep -q "v2.13.0"'
ok runs-as-user sh -c 'su user -c "cmus --version" | head -1 | grep -q v2.13'
ok plugins sh -c 'ls /opt/cmus/lib/cmus/ip/ffmpeg.so /opt/cmus/lib/cmus/op/pulse.so'
ok desktop-entry test -r /usr/share/applications/hildon/cmus.desktop
ok license test -r /opt/cmus/share/doc/cmus/COPYING
ok manual test -r /opt/cmus/share/man/man1/cmus.1.gz
# play a file through the whole chain: the server in tmux, the position must advance (decoder + PulseAudio output)
F=/home/user/MyDocs/nptest/a.mp4
if [ -f $F ]; then
    ok plays-and-advances sh -c "su user -c 'export TERM=xterm; tmux -L cmt kill-server 2>/dev/null; tmux -L cmt new-session -d -x 80 -y 20 cmus; sleep 4; cmus-remote -f $F; sleep 4; cmus-remote -Q > /tmp/cmus-q1; sleep 3; cmus-remote -Q > /tmp/cmus-q2; cmus-remote -C quit; tmux -L cmt kill-server 2>/dev/null; true' && grep -q '^status playing' /tmp/cmus-q1 && [ \$(grep '^position' /tmp/cmus-q2 | cut -d' ' -f2) -gt \$(grep '^position' /tmp/cmus-q1 | cut -d' ' -f2) ]"
    rm -f /tmp/cmus-q1 /tmp/cmus-q2
else
    skip plays-and-advances "no $F"
fi
summary
