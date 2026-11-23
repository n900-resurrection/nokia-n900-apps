#!/bin/bash
# Package chocolate-doom as a .deb for Maemo 5. Run INSIDE the Workshop after build.sh: make -C apps/chocolate-doom deb
# Output: /project/build/deb/chocolate-doom_<VERSION>-<REV>_armel.deb
# NOT TRIED YET (prepared 2026-11-23): the layout of the install tree is a guess, check it after the first build.
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=chocolate-doom
VERSION="${VERSION:-3.1.1}"
OUT="$PROJ/build/out/$PKG-$VERSION"
ROOT="$OUT/root/opt/chocolate-doom"
HERE="$PROJ/apps/chocolate-doom"
STAGE="$PROJ/build/deb/stage-$PKG"
[ -x "$ROOT/bin/chocolate-doom" ] || { echo "Missing build output in $OUT, run build.sh first (make build)"; exit 1; }

rm -rf "$STAGE"; mkdir -p "$STAGE/usr/bin" "$STAGE/opt/chocolate-doom/share/doc/$PKG"
cp -a "$ROOT/." "$STAGE/opt/chocolate-doom/"
install -m 755 "$HERE/chocolate-doom-launch" "$STAGE/opt/chocolate-doom/bin/chocolate-doom-launch"
install -m 644 "$OUT/COPYING.md" "$STAGE/opt/chocolate-doom/share/doc/$PKG/COPYING.md"
for b in "$STAGE"/opt/chocolate-doom/bin/*; do ln -sf "../../opt/chocolate-doom/bin/$(basename "$b")" "$STAGE/usr/bin/$(basename "$b")"; done

debpack_desktop "Chocolate Doom" "/opt/chocolate-doom/bin/chocolate-doom-launch" "$HERE/icon.png"
sed -i 's|^Exec=.*|Exec=/usr/bin/osso-xterm -e /opt/chocolate-doom/bin/chocolate-doom-launch|' "$STAGE/usr/share/applications/hildon/$PKG.desktop"

SECTION=user/games
DEPENDS="libc6 (>= 2.5), libsdl2 (>= 2.30), libsdl2-mixer (>= 2.8)"
DISPLAY_NAME="Chocolate Doom"
SHORT_DESC="Chocolate Doom 3.1.1: Doom, Heretic, Hexen, Strife (needs an IWAD)"
LONG_DESC="Chocolate Doom 3.1.1: a faithful source port of Doom, Heretic, Hexen and Strife on SDL 2 (GPL-2.0). The game data (an IWAD: doom.wad, doom2.wad, freedoom1.wad ...) is not in the package: copy it to /home/user/MyDocs/doom. The music is silent (no MIDI decoder in the SDL2_mixer of this repository), the sound effects work.
Upstream: https://www.chocolate-doom.org/"
MAINTAINER="elPytel (build of upstream Chocolate Doom)"
debpack_build
