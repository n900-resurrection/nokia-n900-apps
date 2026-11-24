TEST_NAME=angband
need_pkg angband
ok binary-present test -x /opt/angband/bin/angband
ok no-missing-libs sh -c '! ldd /opt/angband/bin/angband 2>&1 | grep -q "not found"'
ok link-in-path sh -c 'command -v angband >/dev/null'
ok game-data sh -c 'test -d /opt/angband/share/angband/gamedata || test -d /opt/angband/share/angband'
contains usage "Usage: angband" sh -c '/opt/angband/bin/angband -h 2>&1 || true'
# the game draws its first screen in a terminal (a pty made by python3, TERM=xterm, 8 seconds, then it is stopped)
contains starts-in-terminal "Angband" sh -c 'cd /tmp && TERM=xterm python3 -c "
import os, pty, select, signal, time
pid, fd = pty.fork()
if pid == 0:
    os.execv(\"/opt/angband/bin/angband\", [\"angband\", \"-mgcu\", \"-uTester\", \"-d\", \"/tmp/angband-test\"])
out = b\"\"
end = time.time() + 8
while time.time() < end:
    r, _, _ = select.select([fd], [], [], 0.5)
    if r:
        try: out += os.read(fd, 4096)
        except OSError: break
os.kill(pid, signal.SIGKILL)
print(\"Angband\" if b\"ngband\" in out else repr(out[:200]))
"'
ok menu-entry test -f /usr/share/applications/hildon/angband.desktop
summary
