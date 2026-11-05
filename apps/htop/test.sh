TEST_NAME=htop3
need_pkg htop3
contains version "htop 3.5" htop3 --version
ok link-in-path test -x /usr/bin/htop3
ok system-htop-untouched test -x /opt/maemo/usr/bin/htop
# Run in batch mode: one screen refresh, no tty needed (-C no colours).
ok batch-run sh -c "TERM=xterm htop3 --help >/dev/null"
ok no-missing-libs sh -c "! ldd /opt/htop3/bin/htop 2>&1 | grep -q \"not found\""
summary
