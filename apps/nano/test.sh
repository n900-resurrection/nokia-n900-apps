TEST_NAME=nano
need_pkg nano
ok in-path sh -c 'command -v nano'
ok no-missing-libs sh -c '! ldd /opt/nano/bin/nano 2>&1 | grep -q "not found"'
ok desktop-entry test -r /usr/share/applications/hildon/nano.desktop
ok version sh -c 'nano --version | head -1 | grep -q "GNU nano, version 9"'
ok utf8-support sh -c 'nano --version | grep -q -- "--enable-utf8"'
ok syntax-files test -r /opt/nano/share/nano/sh.nanorc
ok sysconfig test -r /opt/nano/etc/nanorc
# the editor starts in a terminal (a pty from script(1) is not on the phone: TERM=xterm and a closed stdin make nano quit at once)
ok starts-and-quits sh -c 'echo "Ahoj" > /tmp/nano.txt; TERM=xterm nano --ignorercfiles /tmp/nano.txt </dev/null >/dev/null 2>&1; rm -f /tmp/nano.txt; true'
summary
