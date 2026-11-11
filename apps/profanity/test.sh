TEST_NAME=profanity
need_pkg profanity
ok in-path sh -c 'command -v profanity'
ok no-missing-libs sh -c '! ldd /opt/profanity/bin/profanity.bin 2>&1 | grep -q "not found"'
ok no-system-glib-ssl sh -c '! ldd /opt/profanity/bin/profanity.bin 2>&1 | grep -q -e glib -e libssl -e ncurses -e curl'
contains version "Profanity, version 0.19.0" sh -c 'TERM=xterm profanity --version | head -1'
ok ca-bundle sh -c 'test -s /opt/curl/etc/ssl/cacert.pem'
ok data-installed sh -c 'ls /opt/profanity/share/profanity/themes | grep -q mono'
# The interface and the connection to a server were checked by hand in a terminal (screen, TERM=xterm).
summary
