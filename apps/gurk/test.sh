TEST_NAME=gurk
need_pkg gurk
ok in-path sh -c 'command -v gurk'
ok static-binary sh -c '! ldd /opt/gurk/bin/gurk 2>&1 | grep -q "not found"'
t version 'gurk 0.10.2' sh -c 'gurk --version'
ok runs-as-user sh -c 'su user -c "gurk --version" | grep -q "gurk 0.10"'
ok desktop-entry test -r /usr/share/applications/hildon/gurk.desktop
ok license test -r /opt/gurk/share/doc/gurk/LICENSE-AGPL-3.0
summary
