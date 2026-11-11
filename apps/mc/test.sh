TEST_NAME=mc
need_pkg mc
ok in-path sh -c 'command -v mc'
ok no-missing-libs sh -c '! ldd /opt/mc/bin/mc.bin 2>&1 | grep -q "not found"'
ok no-system-glib sh -c '! ldd /opt/mc/bin/mc.bin 2>&1 | grep -q -e glib -e ncurses'
contains version "GNU Midnight Commander 4.8.33" sh -c 'TERM=xterm mc --version | head -1'
ok viewer-links sh -c 'command -v mcview && command -v mcedit'
# mcview prints a file in plain mode (-b would need a terminal); mc -P (print the directory) needs a terminal too, so only the non-interactive parts are tested here.
D=/home/user/mc-test; rm -rf $D; mkdir -p $D; echo hello > $D/a.txt
ok skins-installed sh -c 'ls /opt/mc/share/mc/skins | grep -q default.ini'
ok syntax-installed sh -c 'test -s /opt/mc/share/mc/syntax/Syntax'
rm -rf $D
summary
