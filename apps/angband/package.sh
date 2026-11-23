#!/bin/bash
# Package angband as a .deb for Maemo 5. Run INSIDE the Workshop after build.sh: make -C apps/angband deb
# Output: /project/build/deb/angband_<VERSION>-<REV>_armel.deb
# NOT TRIED YET (prepared 2026-11-23): the layout of the install tree is a guess, check it after the first build.
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=angband
VERSION="${VERSION:-4.2.6}"
OUT="$PROJ/build/out/$PKG-$VERSION"
ROOT="$OUT/root/opt/angband"
HERE="$PROJ/apps/angband"
STAGE="$PROJ/build/deb/stage-$PKG"
[ -x "$ROOT/bin/angband" ] || { echo "Missing build output in $OUT, run build.sh first (make build)"; exit 1; }

rm -rf "$STAGE"; mkdir -p "$STAGE/usr/bin" "$STAGE/opt/angband/share/doc/$PKG"
cp -a "$ROOT/." "$STAGE/opt/angband/"
install -m 644 "$OUT/COPYING" "$STAGE/opt/angband/share/doc/$PKG/COPYING"
for b in "$STAGE"/opt/angband/bin/*; do ln -sf "../../opt/angband/bin/$(basename "$b")" "$STAGE/usr/bin/$(basename "$b")"; done

debpack_desktop "Angband" "/usr/bin/angband" "$HERE/icon.png"

SECTION=user/games
DEPENDS="libc6 (>= 2.5), libncurses5"
DISPLAY_NAME="Angband"
SHORT_DESC="Angband 4.2.6: the classic roguelike in the terminal"
LONG_DESC="Angband 4.2.6: the classic Tolkien roguelike (GPL-2.0), ncurses interface. Saves and scores are in ~/.angband. Start it from the menu (a terminal) or with angband.
Upstream: https://rephial.org/"
MAINTAINER="elPytel (build of upstream Angband)"
debpack_build
