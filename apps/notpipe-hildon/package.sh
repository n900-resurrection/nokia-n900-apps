#!/bin/bash
# Package notpipe-hildon as a .deb for Maemo 5: make -C apps/notpipe-hildon deb
# Output: /project/build/deb/notpipe-hildon_<VERSION>-<REV>_armel.deb
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=notpipe-hildon
VERSION="${VERSION:-0.1}"
STAGE="$PROJ/build/deb/stage-$PKG"
HERE="$PROJ/apps/$PKG"

rm -rf "$STAGE"
mkdir -p "$STAGE/opt/$PKG" "$STAGE/usr/bin" "$STAGE/usr/share/applications/hildon" "$STAGE/DEBIAN"
install -m 755 "$HERE/notpipe-hildon" "$STAGE/opt/$PKG/"
install -m 644 "$HERE/notpipe_core.py" "$HERE/instances.json" "$HERE/README.md" "$STAGE/opt/$PKG/"
for sz in 48 64; do
    mkdir -p "$STAGE/usr/share/icons/hicolor/${sz}x${sz}/apps"
    install -m 644 "$HERE/icons/$sz.png" "$STAGE/usr/share/icons/hicolor/${sz}x${sz}/apps/$PKG.png"
done
ln -s ../../opt/$PKG/notpipe-hildon "$STAGE/usr/bin/notpipe-hildon"
cat > "$STAGE/usr/share/applications/hildon/$PKG.desktop" <<'EOT'
[Desktop Entry]
Encoding=UTF-8
Version=1.0
Type=Application
Name=NotPipe
Icon=notpipe-hildon
Exec=/usr/bin/notpipe-hildon
X-Osso-Type=application/x-executable
EOT

SECTION=user/multimedia
DEPENDS="python3.11, python3-hildonlite (>= 0.5.0), curl, nplay, ffmpeg"
DISPLAY_NAME="NotPipe (YouTube client)"
SHORT_DESC="A YouTube client with a touch interface (Invidious + nplay)"
LONG_DESC="Search for videos, tap one and watch it: the application asks a public Invidious instance (not YouTube itself) for the list of
streams, downloads the picture (H.264) and the sound (AAC), which YouTube keeps in two files, and plays them with nplay, the player of this
project that does 240p smoothly and 360p mostly. 'Save to MyDocs' joins the two files into one MP4 without re-encoding. The settings are the quality,
the sound (normal or small) and the size of the cache; the list of Invidious instances is updated from api.invidious.io once a day and a call tries
instance after instance, skipping those that ask for a browser check. The idea comes from notPipe for old Android phones. Upstream: this project (MIT)."
debpack_build
