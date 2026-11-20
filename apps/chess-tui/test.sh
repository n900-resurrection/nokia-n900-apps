TEST_NAME=chess-tui
need_pkg chess-tui
ok in-path sh -c 'command -v chess-tui'
ok wrapper-keeps-explicit-engine sh -c 'grep -q -e "--engine-path" /usr/bin/chess-tui'
ok static-binary sh -c '! ldd /opt/chess-tui/bin/chess-tui 2>&1 | grep -q "not found"'
t version 'chess-tui 2.8.1' sh -c 'chess-tui --version'
ok runs-as-user sh -c 'su user -c "chess-tui --version" | grep -q "chess-tui 2.8"'
ok desktop-entry test -r /usr/share/applications/hildon/chess-tui.desktop
ok license test -r /opt/chess-tui/share/doc/chess-tui/LICENSE
summary
