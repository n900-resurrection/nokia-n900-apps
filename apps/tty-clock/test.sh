TEST_NAME=tty-clock
need_pkg tty-clock
contains help "usage : tty-clock" tty-clock -h
ok link-in-path test -x /usr/bin/tty-clock
ok desktop-entry test -r /usr/share/applications/hildon/tty-clock.desktop
ok no-missing-libs sh -c "! ldd /opt/tty-clock/bin/tty-clock 2>&1 | grep -q \"not found\""
summary
