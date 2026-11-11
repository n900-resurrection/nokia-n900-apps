TEST_NAME=irssi
need_pkg irssi
ok in-path sh -c 'command -v irssi'
ok no-missing-libs sh -c '! ldd /opt/irssi/bin/irssi.bin 2>&1 | grep -q "not found"'
ok no-system-glib sh -c '! ldd /opt/irssi/bin/irssi.bin 2>&1 | grep -q -e glib -e libssl -e ncurses'
contains version "irssi 1.4.5" irssi --version
ok ca-bundle sh -c 'test -s /opt/curl/etc/ssl/cacert.pem'
contains help "Usage:" irssi --help
# The interface itself was checked by hand in a terminal (ssh -tt n900).
summary
