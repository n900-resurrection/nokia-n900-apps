#!/bin/bash
# Package MaeShare (our build of the client + the files of the author's release) as a .deb for Maemo 5. Run INSIDE the Workshop after build.sh:
#   make -C apps/maeshare deb            Output: /project/build/deb/maeshare_<VERSION>-<REV>_armel.deb
#
# The base is the release package of the author (maeshare_1.0.3_armel.deb of github.com/balancechiang/MaeShare, SHA-256 below): it brings what we cannot build,
# the helper `probe` (LocalSend network core, no published source), the alias word lists, the icons, the menu entry and the sharing plugin.
# On top of it come, from our fork (the sources of build.sh): the program /opt/maeshare/maeshare built here, the QML files and i18n.js (Czech) of both trees
# (/opt/maeshare for CSSU Qt, /opt/maeshare/qml47 for the stock Qt 4.7.0: the same files with `import Qt 4.7`). The version is the author's one plus our revision.
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=maeshare
VERSION="${VERSION:-1.0.3}"
OUT="$PROJ/build/out/$PKG-$VERSION"
STAGE="$PROJ/build/deb/stage-$PKG"
BASE_URL="https://github.com/balancechiang/MaeShare/releases/download/v$VERSION/maeshare_${VERSION}_armel.deb"
BASE_SHA256=8216197db67ff89a112dd4200dbccb1c77f5f2837b1deb74eddc45eff2b9fd5f
[ -x "$OUT/maeshare" ] || { echo "Missing $OUT/maeshare, run build.sh first (make build)"; exit 1; }

BASE="$PROJ/build/downloads/maeshare_${VERSION}_armel.deb"
[ -s "$BASE" ] || curl -fL --retry 3 -o "$BASE" "$BASE_URL"
echo "$BASE_SHA256  $BASE" | sha256sum -c - >/dev/null || { echo "sha256 of the release package differs"; exit 1; }

rm -rf "$STAGE"; mkdir -p "$STAGE"
dpkg-deb -x "$BASE" "$STAGE"
dpkg-deb -e "$BASE" "$STAGE/DEBIAN"; rm -f "$STAGE/DEBIAN/control"   # postinst and prerm are kept, the control file is made again
M="$STAGE/opt/maeshare"
install -m 755 "$OUT/maeshare" "$M/maeshare"
Q="$OUT/src/src/app/qml"
cp "$Q"/*.qml "$Q/i18n.js" "$M/"
rm -rf "$M/icons" "$M/qml47"; mkdir -p "$M/qml47"
cp -a "$Q/icons" "$M/icons"
cp "$Q"/*.png "$M/"
# the QML of the stock Qt: the same files, the Qt Quick 1 import under its old name
for f in "$M"/*.qml; do sed 's/^import QtQuick 1\.0$/import Qt 4.7/' "$f" > "$M/qml47/$(basename "$f")"; done
cp "$M/i18n.js" "$M/qml47/i18n.js"; cp -a "$M/icons" "$M/qml47/icons"; cp "$M"/*.png "$M/qml47/"
grep -q '^import Qt 4.7$' "$M/qml47/Main.qml" || { echo "qml47/Main.qml has no 'import Qt 4.7'"; exit 1; }
mkdir -p "$M/share/doc/maeshare"
cp "$OUT/src/LICENSE" "$OUT/src/NOTICE" "$M/share/doc/maeshare/"

DEBPACK_ICON="$M/icon.png"
SECTION=user/network
DEPENDS="libqt4-declarative, libqt4-gui, libqt4-network, libqt4-core, libqt4-svg"
DISPLAY_NAME="MaeShare"
SHORT_DESC="MaeShare: LocalSend client, file transfer in the local network"
LONG_DESC="MaeShare $VERSION by Chih (Apache-2.0), a client of the LocalSend protocol for the N900: send and receive files, photos and text with other
LocalSend devices (phones, computers) in the same Wi-Fi, directly and encrypted, without a server. This build comes from the fork
https://github.com/n900-resurrection/MaeShare: a Czech translation, and a fix for phones whose language is not English (the helper printed a warning into its
output and sending failed with \"Device information unreadable\"). The helper program, the icons and the sharing plugin are those of the author's release $VERSION."
debpack_build
