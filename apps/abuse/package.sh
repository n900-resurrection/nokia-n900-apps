#!/bin/bash
# Package abuse as a .deb for Maemo 5. Run INSIDE the Workshop after build.sh: make -C apps/abuse deb
# Output: /project/build/deb/abuse_<VERSION>-<REV>_armel.deb
# Tried on the phone 2026-11-23: the game needs SDL_RENDER_DRIVER=software, which the launcher abuse-launch sets.
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=abuse
VERSION="${VERSION:-0.9.1}"
OUT="$PROJ/build/out/$PKG-$VERSION"
ROOT="$OUT/root/opt/abuse"
HERE="$PROJ/apps/abuse"
STAGE="$PROJ/build/deb/stage-$PKG"
[ -x "$ROOT/bin/abuse" ] || { echo "Missing build output in $OUT, run build.sh first (make build)"; exit 1; }

rm -rf "$STAGE"; mkdir -p "$STAGE/usr/bin" "$STAGE/opt/abuse/share/doc/$PKG"
cp -a "$ROOT/." "$STAGE/opt/abuse/"
install -m 644 "$OUT/COPYING" "$STAGE/opt/abuse/share/doc/$PKG/COPYING"
for b in "$STAGE"/opt/abuse/bin/*; do ln -sf "../../opt/abuse/bin/$(basename "$b")" "$STAGE/usr/bin/$(basename "$b")"; done

rm -f "$STAGE/usr/bin/abuse"
install -m 755 "$HERE/abuse-launch" "$STAGE/usr/bin/abuse"
debpack_desktop "Abuse" "/usr/bin/abuse" "$HERE/icon.png"
sed -i 's|^Exec=.*|Exec=/usr/bin/abuse|' "$STAGE/usr/share/applications/hildon/$PKG.desktop"

SECTION=user/games
DEPENDS="libc6 (>= 2.5), libsdl2 (>= 2.30), libsdl2-mixer (>= 2.8)"
DISPLAY_NAME="Abuse"
SHORT_DESC="Abuse: the 1996 run-and-gun, SDL 2 port with the game data"
LONG_DESC="Abuse by Crack dot Com (1996): a side-scrolling run-and-gun with a Lisp-scripted engine, the SDL 2 port of Xenoveritas (the free game data is included, but not the sound and music, so the game is silent: the code and the shareware data are public domain, the port GPL-2.0 and WTFPL). Start it from the menu; the keyboard moves, the mouse aims.
Upstream: https://github.com/Xenoveritas/abuse"
MAINTAINER="elPytel (build of upstream Abuse)"
debpack_build
