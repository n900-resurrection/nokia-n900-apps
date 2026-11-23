TEST_NAME=nxengine-evo
need_pkg nxengine-evo
ok binaries-present sh -c 'test -x /opt/nxengine-evo/bin/nxengine-evo && test -x /opt/nxengine-evo/bin/nxextract'
ok no-missing-libs sh -c '! ldd /opt/nxengine-evo/bin/nxengine-evo 2>&1 | grep -q "not found"'
ok engine-data sh -c 'test -s /opt/nxengine-evo/share/nxengine/data/sprites.sif && test -s /opt/nxengine-evo/share/nxengine/data/system.json'
ok links-in-path sh -c 'command -v nxengine-evo >/dev/null && command -v nxengine-evo-setup >/dev/null'
ok menu-entry test -f /usr/share/applications/hildon/nxengine-evo.desktop
# without the game data the launcher says so (a throw-away HOME: the real data of the phone is not touched)
t check-without-data "data: missing" sh -c 'HOME=/tmp/nxe-test XDG_DATA_HOME=/tmp/nxe-test/share nxengine-evo --check'
contains setup-without-exe "Doukutsu.exe not found" sh -c 'HOME=/tmp/nxe-test XDG_DATA_HOME=/tmp/nxe-test/share nxengine-evo-setup /nonexistent'
contains extract-without-exe "Can't open Doukutsu.exe" sh -c 'mkdir -p /tmp/nxe-test && cd /tmp/nxe-test && /opt/nxengine-evo/bin/nxextract'
# with extracted data (here a stand-in file) the check passes
ok check-with-data sh -c 'mkdir -p /tmp/nxe-test/share/nxengine/data && echo x > /tmp/nxe-test/share/nxengine/data/stage.dat && HOME=/tmp/nxe-test XDG_DATA_HOME=/tmp/nxe-test/share nxengine-evo --check | grep -q "data: ok"'
rm -rf /tmp/nxe-test
summary
