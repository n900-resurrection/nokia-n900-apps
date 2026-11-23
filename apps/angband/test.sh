TEST_NAME=angband
need_pkg angband
ok binary-present test -x /opt/angband/bin/angband
ok no-missing-libs sh -c '! ldd /opt/angband/bin/angband 2>&1 | grep -q "not found"'
ok link-in-path sh -c 'command -v angband >/dev/null'
ok game-data sh -c 'test -d /opt/angband/share/angband/gamedata || test -d /opt/angband/share/angband'
contains version "Angband 4.2" sh -c '/opt/angband/bin/angband -v 2>&1 || true'
ok menu-entry test -f /usr/share/applications/hildon/angband.desktop
summary
