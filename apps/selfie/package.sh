#!/bin/bash
# Package selfie as a .deb for Maemo 5: make -C apps/selfie deb
# Output: /project/build/deb/selfie_<VERSION>-<REV>_armel.deb
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=selfie
VERSION="${VERSION:-0.5}"
STAGE="$PROJ/build/deb/stage-$PKG"
HERE="$PROJ/apps/selfie"

rm -rf "$STAGE"
mkdir -p "$STAGE/opt/$PKG/icons" "$STAGE/usr/bin" "$STAGE/usr/share/applications/hildon"
install -m 755 "$HERE/selfie" "$STAGE/opt/$PKG/selfie"
install -m 644 "$HERE"/icons/ui-*.png "$STAGE/opt/$PKG/icons/"
for sz in 48 64; do
    mkdir -p "$STAGE/usr/share/icons/hicolor/${sz}x${sz}/apps"
    install -m 644 "$HERE/icons/$sz.png" "$STAGE/usr/share/icons/hicolor/${sz}x${sz}/apps/$PKG.png"
done
ln -s ../../opt/$PKG/selfie "$STAGE/usr/bin/selfie"
cat > "$STAGE/usr/share/applications/hildon/$PKG.desktop" <<'EOT'
[Desktop Entry]
Encoding=UTF-8
Version=1.0
Type=Application
Name=Selfie
Icon=selfie
Exec=/usr/bin/selfie
X-Osso-Type=application/x-executable
EOT

SECTION=user/multimedia
DEPENDS="python3.11, python3-hildonlite (>= 0.2.2), gstreamer0.10-plugins-camera"
DISPLAY_NAME="Selfie"
SHORT_DESC="Live preview of the front camera, a photo button and the camera button (test application)"
LONG_DESC="Shows what the camera sees (front by default, a button switches to the back one) and saves a JPEG to ~/MyDocs/DCIM. Written in Python 3 with hildonlite and GStreamer through ctypes, it is mainly a test of the cameras. The camera has one reader: close the stock Camera application first."
debpack_build
