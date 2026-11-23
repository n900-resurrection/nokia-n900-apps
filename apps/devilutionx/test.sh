TEST_NAME=devilutionx
need_pkg devilutionx
ok binary-present test -x /opt/devilutionx/bin/devilutionx
ok no-missing-libs sh -c '! ldd /opt/devilutionx/bin/devilutionx 2>&1 | grep -q "not found"'
ok menu-entry test -f /usr/share/applications/hildon/devilutionx.desktop
contains version "devilutionx" sh -c '/opt/devilutionx/bin/devilutionx --version 2>&1 | tr A-Z a-z'
# without game data the launcher says where to put it (a throw-away HOME and XDG_DATA_HOME)
contains launcher-without-data "No game data" sh -c 'HOME=/tmp/dx-test XDG_DATA_HOME=/tmp/dx-test/share /opt/devilutionx/bin/devilutionx-launch </dev/null'
summary
