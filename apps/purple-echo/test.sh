TEST_NAME=purple-echo
need_pkg purple-echo
ok plugin-file test -f /opt/purple-echo/lib/libecho.so
ok plugin-linked test -L /usr/lib/purple-2/libecho.so
ok plugin-entry sh -c 'grep -q purple_init_plugin /opt/purple-echo/lib/libecho.so && grep -q prpl-echo /opt/purple-echo/lib/libecho.so'
ok manager-block sh -c 'grep -q "^\[Protocol echo\]" /usr/share/telepathy/managers/haze.manager'
ok manager-backup test -f /usr/share/telepathy/managers/haze.manager.orig-echo
ok profile sh -c 'grep -q "^Protocol=echo" /usr/share/osso-rtcom/echo.profile'
ok icon test -f /usr/share/icons/hicolor/48x48/hildon/im-echo.png
summary
