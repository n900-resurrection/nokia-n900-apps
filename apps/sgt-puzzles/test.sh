TEST_NAME=sgt-puzzles
need_pkg sgt-puzzles
ok launcher-present test -x /opt/sgt-puzzles/bin/puzzles
ok forty-puzzles sh -c '[ "$(ls /opt/sgt-puzzles/bin | grep -c "^sgt-")" -ge 40 ]'
ok list-matches sh -c '[ "$(wc -l < /opt/sgt-puzzles/share/puzzles.list)" -ge 40 ] && while IFS="|" read n t d; do [ -x /opt/sgt-puzzles/bin/sgt-$n ] || exit 1; done < /opt/sgt-puzzles/share/puzzles.list'
ok links-in-path sh -c 'command -v sgt-net >/dev/null && command -v sgt-mines >/dev/null'
ok no-missing-libs sh -c '! ldd /opt/sgt-puzzles/bin/sgt-net /opt/sgt-puzzles/bin/puzzles 2>&1 | grep -q "not found"'
ok menu-entry test -f /usr/share/applications/hildon/sgt-puzzles.desktop
# the puzzles are GTK programs: they need the X server of the phone; with a display, start one and check that it stays running for a second
if [ -n "${DISPLAY:-}" ]; then
    ok starts sh -c 'sgt-net & p=$!; sleep 2; kill -0 $p; r=$?; kill $p; exit $r'
else
    skip starts "no X display here: run  sgt-net  on the phone"
fi
summary
