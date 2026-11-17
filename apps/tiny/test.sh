TEST_NAME=tiny
need_pkg tiny
ok launcher-in-path test -x /usr/bin/tiny
ok network-installed test -s /opt/tiny/share/tiny/TINY.BIN
contains answer-paris "Paris" sh -c 'echo "what is the capital of france" | tiny /P'
contains answer-sum "12" sh -c 'echo "what is 7 plus 5" | tiny /P'
ok desktop-entry test -r /usr/share/applications/hildon/tiny.desktop
ok no-missing-libs sh -c "! ldd /opt/tiny/bin/tiny-bin 2>&1 | grep -q \"not found\""
ok man-page test -r /opt/tiny/share/man/man1/tiny.1.gz
summary
