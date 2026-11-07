TEST_NAME=ranger
need_pkg ranger
need_pkg python3.11
export TERM=xterm
ok tool-in-path sh -c 'command -v ranger'
ok desktop-entry test -r /usr/share/applications/hildon/ranger.desktop
ok precompiled sh -c 'test -n "$(find /opt/ranger/lib/ranger/core -name "*.pyc" | head -1)"'
contains version "ranger version: ranger 1.9.4" ranger --version
contains python-3-11 "Python version: 3.11" ranger --version
# rifle.conf for the phone: which command rifle picks for a file (the files are only listed, nothing is started).
export PATH="$PATH:/opt/ranger/libexec"
RIFLE="/opt/python3/bin/python3.11 /opt/ranger/lib/ranger/ext/rifle.py -c /opt/ranger/lib/ranger/config/rifle.conf -l"
rm -rf /tmp/rg-t; mkdir -p /tmp/rg-t
cd /tmp/rg-t
echo x > a.png; echo x > b.mp3; echo x > c.pdf; echo x > d.html; echo hello > e.txt; echo x > f.mp4; printf '\000\001\002\003' > g.bin; echo hi > noext
ok libexec-files sh -c 'test -x /opt/ranger/libexec/hildon-open && test -x /opt/ranger/libexec/file'
contains rifle-image "hildon-open image_viewer" $RIFLE /tmp/rg-t/a.png
contains rifle-audio "hildon-open mediaplayer" $RIFLE /tmp/rg-t/b.mp3
contains rifle-pdf "hildon-open osso_pdfviewer" $RIFLE /tmp/rg-t/c.pdf
contains rifle-html "hildon-open browser" $RIFLE /tmp/rg-t/d.html
contains rifle-video "hildon-open mediaplayer" $RIFLE /tmp/rg-t/f.mp4
contains rifle-text "editor" $RIFLE /tmp/rg-t/e.txt
contains rifle-file-without-extension "editor" $RIFLE /tmp/rg-t/noext
# the stand-in of file(1)
t file-text 'text/plain' file --mime-type -Lb /tmp/rg-t/e.txt
t file-directory 'inode/directory' file --mime-type -Lb /tmp/rg-t
t file-binary 'application/octet-stream' file --mime-type -Lb /tmp/rg-t/g.bin
# hildon-open: the D-Bus call (HILDON_OPEN_DRY only prints it); spaces and # in the name are encoded
echo x > "/tmp/rg-t/a b#c.mp3"
contains hildon-open-uri "com.nokia.mediaplayer.mime_open string:file:///tmp/rg-t/a%20b%23c.mp3" env HILDON_OPEN_DRY=1 hildon-open mediaplayer "/tmp/rg-t/a b#c.mp3"
contains hildon-open-browser "com.nokia.osso_browser.load_url string:file:///tmp/rg-t/d.html" env HILDON_OPEN_DRY=1 hildon-open browser /tmp/rg-t/d.html
cd /
rm -rf /tmp/rg-t
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
