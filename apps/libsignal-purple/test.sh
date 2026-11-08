TEST_NAME=libsignal-purple
need_pkg libsignal-purple
ok plugin-file test -f /opt/libsignal-purple/lib/libsignal.so
ok plugin-linked test -L /usr/lib/purple-2/libsignal.so
ok plugin-entry sh -c 'grep -q purple_init_plugin /opt/libsignal-purple/lib/libsignal.so && grep -q prpl-signal /opt/libsignal-purple/lib/libsignal.so'
ok manager-block sh -c 'grep -q "^\[Protocol signal\]" /usr/share/telepathy/managers/haze.manager'
ok manager-backup test -f /usr/share/telepathy/managers/haze.manager.orig-signal
ok profile sh -c 'grep -q "^Protocol=signal" /usr/share/osso-rtcom/signal.profile'
ok icon test -f /usr/share/icons/hicolor/48x48/hildon/im-signal.png
ok daemon-installed test -x /opt/signal-bridge/bin/signal-bridge
ok starter-installed test -x /opt/signal-bridge/bin/signal-bridge-start
summary
