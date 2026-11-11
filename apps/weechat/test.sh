TEST_NAME=weechat
need_pkg weechat
ok in-path sh -c 'command -v weechat'
ok no-missing-libs sh -c '! ldd /opt/weechat/bin/weechat 2>&1 | grep -q "not found"'
ok plugins-installed sh -c 'ls /opt/weechat/lib/weechat/plugins/ | grep -q irc.so'
ok plugins-no-missing-libs sh -c 'for f in /opt/weechat/lib/weechat/plugins/*.so; do ldd $f 2>&1 | grep -q "not found" && exit 1; done; exit 0'
contains version "4.10.4" sh -c 'TERM=xterm weechat --version'
ok ca-bundle sh -c 'test -s /opt/curl/etc/ssl/cacert.pem'
# The interface and the connection to a server were checked by hand in a terminal (screen, TERM=xterm).
summary
