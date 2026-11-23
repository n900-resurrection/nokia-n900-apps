TEST_NAME=chocolate-doom
need_pkg chocolate-doom
ok binaries-present sh -c 'test -x /opt/chocolate-doom/bin/chocolate-doom && test -x /opt/chocolate-doom/bin/chocolate-doom-launch'
ok no-missing-libs sh -c '! ldd /opt/chocolate-doom/bin/chocolate-doom 2>&1 | grep -q "not found"'
contains version "Chocolate Doom" sh -c 'SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy /opt/chocolate-doom/bin/chocolate-doom -version 2>&1 || true'
ok menu-entry test -f /usr/share/applications/hildon/chocolate-doom.desktop
# without an IWAD the launcher says where to put one (a throw-away HOME; the folder MyDocs/doom of the phone may hold a WAD: then the test is skipped)
if [ -z "$(ls /home/user/MyDocs/doom/*.wad /home/user/MyDocs/doom/*.WAD 2>/dev/null | head -1)" ]; then
    contains launcher-without-wad "No IWAD found" sh -c 'HOME=/tmp/choc-test /opt/chocolate-doom/bin/chocolate-doom-launch </dev/null'
else
    skip launcher-without-wad "there is a WAD in /home/user/MyDocs/doom"
fi
summary
