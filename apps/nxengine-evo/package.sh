#!/bin/bash
# Package NXEngine-evo as a .deb for Maemo 5. Run INSIDE the Workshop after build.sh: make -C apps/nxengine-evo deb
# Output: /project/build/deb/nxengine-evo_<VERSION>-<REV>_armel.deb
# The package has the engine and its own data (sprites, fonts, scripts of the engine); the game data of Cave Story (Doukutsu.exe) is extracted by the player
# with nxengine-evo-setup into ~/.local/share/nxengine/data. The menu entry starts nxengine-evo-launch: the setup the first time, the game afterwards.
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=nxengine-evo
UPSTREAM="${VERSION:-2.6.5-1}"
VERSION="${UPSTREAM//-/.}"      # 2.6.5.1: a hyphen would end the upstream version of the package version
OUT="$PROJ/build/out/$PKG-$UPSTREAM"
ROOT="$OUT/root/opt/nxengine-evo"
HERE="$PROJ/apps/nxengine-evo"
STAGE="$PROJ/build/deb/stage-$PKG"
ICON="$ROOT/share/icons/hicolor/256x256/apps/org.nxengine.nxengine_evo.png"
[ -x "$ROOT/bin/nxengine-evo" ] || { echo "Missing build output in $OUT, run build.sh first (make build)"; exit 1; }
[ -s "$ICON" ] || { echo "Missing the icon $ICON"; exit 1; }

rm -rf "$STAGE"; mkdir -p "$STAGE/usr/bin" "$STAGE/opt/nxengine-evo/share/doc/$PKG"
mkdir -p "$STAGE/opt/nxengine-evo/share"
cp -a "$ROOT/bin" "$STAGE/opt/nxengine-evo/"
cp -a "$ROOT/share/nxengine" "$STAGE/opt/nxengine-evo/share/"
install -m 755 "$HERE/nxengine-evo-setup" "$HERE/nxengine-evo-launch" "$STAGE/opt/nxengine-evo/bin/"
install -m 644 "$OUT/LICENSE" "$HERE/README.md" "$STAGE/opt/nxengine-evo/share/doc/$PKG/"
ln -s ../../opt/nxengine-evo/bin/nxengine-evo-launch "$STAGE/usr/bin/nxengine-evo"
ln -s ../../opt/nxengine-evo/bin/nxengine-evo-setup "$STAGE/usr/bin/nxengine-evo-setup"
debpack_desktop "NXEngine-evo (Cave Story)" "/opt/nxengine-evo/bin/nxengine-evo-launch" "$ICON"
# a graphical program (the launcher opens a terminal itself for the setup): no terminal
sed -i 's|^Exec=.*|Exec=/opt/nxengine-evo/bin/nxengine-evo-launch|' "$STAGE/usr/share/applications/hildon/$PKG.desktop"

SECTION=user/games
DEPENDS="libc6 (>= 2.5), libpng12-0, libjpeg62, libsdl2 (>= 2.30), libsdl2-image (>= 2.8), libsdl2-mixer (>= 2.8)"
DISPLAY_NAME="NXEngine-evo (Cave Story)"
SHORT_DESC="NXEngine-evo $VERSION: the Cave Story engine (needs the freeware Doukutsu.exe)"
LONG_DESC="NXEngine-evo $VERSION: an open source engine for Cave Story (Cave Story is a freeware game by Daisuke Amaya, not part of this package). Copy the whole folder of the English Cave Story (Doukutsu.exe and the folder data) to the phone and run nxengine-evo-setup /home/user/MyDocs/CaveStory (the menu entry does it the first time, searching MyDocs). Needs libsdl2, libsdl2-image and libsdl2-mixer of this repository. GPL-3.0, the sources are unchanged.
Upstream: https://github.com/nxengine/nxengine-evo"
MAINTAINER="elPytel (build of upstream NXEngine-evo)"
debpack_build
