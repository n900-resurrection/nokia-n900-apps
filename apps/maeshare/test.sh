TEST_NAME=maeshare
need_pkg maeshare
ok binary-present test -x /opt/maeshare/maeshare
ok helper-is-a-binary sh -c 'head -c 4 /opt/maeshare/probe | grep -q ELF'
ok no-missing-libs sh -c '! ldd /opt/maeshare/maeshare 2>&1 | grep -q "not found"'
ok menu-entry test -f /usr/share/applications/hildon/maeshare.desktop
ok sharing-plugin test -f /usr/lib/sharing/plugins/libmaeshare.so
# both QML trees: CSSU Qt (import QtQuick 1.0) and stock Qt (import Qt 4.7)
contains qml-cssu "import QtQuick 1.0" head -8 /opt/maeshare/Main.qml
contains qml-stock "import Qt 4.7" head -8 /opt/maeshare/qml47/Main.qml
# Czech translation in both trees
contains czech-cssu "Čeština" grep -m1 Čeština /opt/maeshare/i18n.js
contains czech-stock "Čeština" grep -m1 Čeština /opt/maeshare/qml47/i18n.js
# the helper answers with a czech locale without disturbing its output (the bug of the fix: the warning in front of the JSON): the usage line is the first line
contains helper-usage "PROBE_ERROR" sh -c 'LANG=cs_CZ LC_ALL=cs_CZ /opt/maeshare/probe 2>&1 | head -3'
summary
