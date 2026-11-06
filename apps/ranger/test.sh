TEST_NAME=ranger
need_pkg ranger
need_pkg python3.11
export TERM=xterm
ok tool-in-path sh -c 'command -v ranger'
ok desktop-entry test -r /usr/share/applications/hildon/ranger.desktop
ok precompiled sh -c 'test -n "$(find /opt/ranger/lib/ranger/core -name "*.pyc" | head -1)"'
contains version "ranger version: ranger 1.9.4" ranger --version
contains python-3-11 "Python version: 3.11" ranger --version
# The text interface needs a terminal: start it in a pseudo terminal, wait for the first screen, quit with q.
cat > /tmp/ranger-pty.py <<'PY'
import os, pty, time, select, fcntl, termios, struct
t0 = time.time()
pid, fd = pty.fork()
if pid == 0:
    os.environ['TERM'] = 'xterm'
    os.execv('/usr/bin/ranger', ['ranger', '/opt/ranger/share/doc/ranger'])
fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack('HHHH', 24, 80, 0, 0))
buf = b''; seen = None; sent = False
while time.time() - t0 < 60:
    r, _, _ = select.select([fd], [], [], 0.5)
    if r:
        try:
            d = os.read(fd, 65536)
        except OSError:
            break
        if not d:
            break
        buf += d
        if seen is None and b'CHANGELOG.md' in buf:
            seen = time.time()
    if seen and not sent and time.time() - seen > 1:
        os.write(fd, b'q'); sent = True
st = os.waitpid(pid, 0)[1]
print('listing=%s exit=%d' % ('yes' if seen else 'no', st))
PY
contains tui-lists-directory "listing=yes exit=0" /opt/python3/bin/python3.11 /tmp/ranger-pty.py
rm -f /tmp/ranger-pty.py
summary
