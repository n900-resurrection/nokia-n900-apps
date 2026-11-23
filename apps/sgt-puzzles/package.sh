#!/bin/bash
# Package Simon Tatham's Puzzles as a .deb for Maemo 5. Run INSIDE the Workshop after build.sh: make -C apps/sgt-puzzles deb
# Output: /project/build/deb/sgt-puzzles_<VERSION>-<REV>_armel.deb
# One menu entry ("Puzzles", the launcher); the puzzle programs are /opt/sgt-puzzles/bin/sgt-<name>, with links in /usr/bin.
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=sgt-puzzles
VERSION="${VERSION:-20250730}"
OUT="$PROJ/build/out/$PKG-$VERSION"
ROOT="$OUT/root/opt/sgt-puzzles"
HERE="$PROJ/apps/sgt-puzzles"
STAGE="$PROJ/build/deb/stage-$PKG"
[ -x "$ROOT/bin/puzzles" ] || { echo "Missing build output in $OUT, run build.sh first (make build)"; exit 1; }

rm -rf "$STAGE"; mkdir -p "$STAGE/usr/bin" "$STAGE/opt/sgt-puzzles/share/doc/$PKG"
cp -a "$ROOT/bin" "$STAGE/opt/sgt-puzzles/"
install -m 644 "$ROOT/share/puzzles.list" "$STAGE/opt/sgt-puzzles/share/puzzles.list"
install -m 644 "$OUT/LICENCE" "$STAGE/opt/sgt-puzzles/share/doc/$PKG/LICENCE"
for b in "$STAGE"/opt/sgt-puzzles/bin/*; do ln -s "../../opt/sgt-puzzles/bin/$(basename "$b")" "$STAGE/usr/bin/$(basename "$b")"; done
debpack_desktop "Puzzles" "/opt/sgt-puzzles/bin/puzzles" "$HERE/icon.png"
# a GTK program, not a console one: no terminal
sed -i 's|^Exec=.*|Exec=/opt/sgt-puzzles/bin/puzzles|' "$STAGE/usr/share/applications/hildon/$PKG.desktop"

SECTION=user/games
DEPENDS="libc6 (>= 2.5), libgtk2.0-0, libhildon1"
DISPLAY_NAME="Puzzles"
SHORT_DESC="Simon Tatham's Portable Puzzle Collection: 40 logic puzzles"
LONG_DESC="Simon Tatham's Portable Puzzle Collection ($VERSION): Net, Mines, Towers, Loopy, Solo (Sudoku), Pattern, Map, Tents, Bridges, Galaxies and 30 more logic puzzles, each with endless random games, hints, undo and saving. The menu entry Puzzles lists them in big buttons; every puzzle is also a program, /usr/bin/sgt-<name> (sgt-net, sgt-mines, ...). Every puzzle has a Type menu for the size and difficulty and a Help menu with its rules and controls.
GTK 2 build for Maemo 5, MIT licence. Upstream: https://www.chiark.greenend.org.uk/~sgtatham/puzzles/"
MAINTAINER="elPytel (build of upstream puzzles by Simon Tatham)"
debpack_build
