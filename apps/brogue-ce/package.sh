#!/bin/bash
# Package Brogue CE as a .deb for Maemo 5. Run INSIDE the Workshop after build.sh: make -C apps/brogue-ce deb
# Output: /project/build/deb/brogue-ce_<VERSION>-<REV>_armel.deb
# Two menu entries: Brogue CE (graphical, SDL 2) and Brogue CE (terminal); commands /usr/bin/brogue-ce (graphical) and /usr/bin/brogue-ce-term.
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=brogue-ce
VERSION="${VERSION:-1.14.1}"
OUT="$PROJ/build/out/$PKG-$VERSION"
ROOT="$OUT/root/opt/brogue-ce"
HERE="$PROJ/apps/brogue-ce"
STAGE="$PROJ/build/deb/stage-$PKG"
[ -x "$ROOT/bin/brogue" ] || { echo "Missing build output in $OUT, run build.sh first (make build)"; exit 1; }

rm -rf "$STAGE"; mkdir -p "$STAGE/usr/bin" "$STAGE/opt/brogue-ce/share/doc/$PKG"
cp -a "$ROOT/bin" "$ROOT/share" "$STAGE/opt/brogue-ce/"
install -m 755 "$HERE/brogue-sdl" "$HERE/brogue-term" "$STAGE/opt/brogue-ce/bin/"
install -m 644 "$OUT/LICENSE.txt" "$OUT/CHANGELOG.md" "$STAGE/opt/brogue-ce/share/doc/$PKG/"
ln -s ../../opt/brogue-ce/bin/brogue-sdl "$STAGE/usr/bin/brogue-ce"
ln -s ../../opt/brogue-ce/bin/brogue-term "$STAGE/usr/bin/brogue-ce-term"
# the terminal entry first (debpack_desktop: osso-xterm -e, icon files), then the graphical one that needs no terminal
debpack_desktop "Brogue CE (terminal)" "/opt/brogue-ce/bin/brogue-term" "$HERE/icon.png"
cat > "$STAGE/usr/share/applications/hildon/$PKG-sdl.desktop" <<'EOT'
[Desktop Entry]
Encoding=UTF-8
Version=1.0
Type=Application
Name=Brogue CE
Icon=brogue-ce
Exec=/opt/brogue-ce/bin/brogue-sdl
X-Osso-Type=application/x-executable
EOT

SECTION=user/games
DEPENDS="libc6 (>= 2.5), libncurses5, libsdl2 (>= 2.30), libsdl2-image (>= 2.8)"
DISPLAY_NAME="Brogue CE"
SHORT_DESC="Brogue CE $VERSION: the roguelike of 26 dungeon levels, graphical and terminal"
LONG_DESC="Brogue Community Edition $VERSION (Brian Walker, Tom Mewett and contributors): a roguelike with no experience points and no grind, 26 levels, allies, a few items that you choose to use cleverly. Two menu entries: Brogue CE (graphical, SDL 2: click or tap to move, keys hjklyubn or the arrow keys) and Brogue CE (terminal, ncurses). Saves and high scores are in ~/.brogue-ce. AGPL-3.0, the sources are unchanged.
Upstream: https://github.com/tmewett/BrogueCE"
MAINTAINER="elPytel (build of upstream Brogue CE)"
debpack_build
