TEST_NAME=brogue-ce
need_pkg brogue-ce
ok binary-present test -x /opt/brogue-ce/bin/brogue
ok no-missing-libs sh -c '! ldd /opt/brogue-ce/bin/brogue 2>&1 | grep -q "not found"'
contains version "CE 1.14" /opt/brogue-ce/bin/brogue --version
ok data-files sh -c 'test -s /opt/brogue-ce/share/assets/tiles.png && test -s /opt/brogue-ce/share/keymap.txt'
ok links-in-path sh -c 'command -v brogue-ce >/dev/null && command -v brogue-ce-term >/dev/null'
ok menu-entries sh -c 'test -f /usr/share/applications/hildon/brogue-ce.desktop && test -f /usr/share/applications/hildon/brogue-ce-sdl.desktop'
# the game logic without a screen: the same seed always gives the same items (a catalog of the first levels)
t seed-catalog-stable 0 sh -c 'a=$(/opt/brogue-ce/bin/brogue --print-seed-catalog 1 3 2 2>&1 | md5sum); b=$(/opt/brogue-ce/bin/brogue --print-seed-catalog 1 3 2 2>&1 | md5sum); [ "$a" = "$b" ] && echo 0 || echo 1' 
contains seed-catalog-items "Depth" /opt/brogue-ce/bin/brogue --print-seed-catalog 1 1 2
summary
