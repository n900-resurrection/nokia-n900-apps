#!/bin/bash
# Package devilutionx as a .deb for Maemo 5. Run INSIDE the Workshop after build.sh: make -C apps/devilutionx deb
# Output: /project/build/deb/devilutionx_<VERSION>-<REV>_armel.deb
# NOT TRIED YET (prepared 2026-11-23): the layout of the install tree is a guess, check it after the first build.
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=devilutionx
VERSION="${VERSION:-1.5.5}"
OUT="$PROJ/build/out/$PKG-$VERSION"
ROOT="$OUT/root/opt/devilutionx"
HERE="$PROJ/apps/devilutionx"
STAGE="$PROJ/build/deb/stage-$PKG"
[ -x "$ROOT/bin/devilutionx" ] || { echo "Missing build output in $OUT, run build.sh first (make build)"; exit 1; }

rm -rf "$STAGE"; mkdir -p "$STAGE/usr/bin" "$STAGE/opt/devilutionx/share/doc/$PKG"
cp -a "$ROOT/." "$STAGE/opt/devilutionx/"
install -m 755 "$HERE/devilutionx-launch" "$STAGE/opt/devilutionx/bin/devilutionx-launch"
install -m 644 "$OUT/LICENSE.md" "$STAGE/opt/devilutionx/share/doc/$PKG/LICENSE.md"
for b in "$STAGE"/opt/devilutionx/bin/*; do ln -sf "../../opt/devilutionx/bin/$(basename "$b")" "$STAGE/usr/bin/$(basename "$b")"; done

debpack_desktop "DevilutionX" "/opt/devilutionx/bin/devilutionx-launch" "$HERE/icon.png"
sed -i 's|^Exec=.*|Exec=/usr/bin/osso-xterm -e /opt/devilutionx/bin/devilutionx-launch|' "$STAGE/usr/share/applications/hildon/$PKG.desktop"

SECTION=user/games
DEPENDS="libc6 (>= 2.5), libsdl2 (>= 2.30), libsdl2-image (>= 2.8)"
DISPLAY_NAME="DevilutionX"
SHORT_DESC="DevilutionX 1.5.5: the Diablo 1 engine (needs DIABDAT.MPQ or spawn.mpq)"
LONG_DESC="DevilutionX 1.5.5: an engine for Diablo 1 (the game data, DIABDAT.MPQ or the shareware spawn.mpq, is not in the package: copy it to ~/.local/share/diasurgical/devilution/). No network play. Heavy for the phone: try it on the shareware first.
Upstream: https://github.com/diasurgical/devilutionX"
MAINTAINER="elPytel (build of upstream DevilutionX)"
debpack_build
