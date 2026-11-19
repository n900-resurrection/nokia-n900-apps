#!/bin/bash
# Package the built nplay as a .deb for Maemo 5. Run INSIDE the Workshop after build.sh: make -C apps/nplay deb
# Output: /project/build/deb/nplay_<VERSION>-<REV>_armel.deb
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=nplay
VERSION="${VERSION:-0.1}"
FFVERSION="${FFVERSION:-9.0.2}"
OUT="$PROJ/build/out/$PKG-$VERSION"
FFSRC="$PROJ/build/src/ffmpeg-$FFVERSION"
STAGE="$PROJ/build/deb/stage-$PKG"
[ -x "$OUT/$PKG" ] || { echo "Missing $OUT/$PKG, run build.sh first (make build)"; exit 1; }

rm -rf "$STAGE"
mkdir -p "$STAGE/opt/$PKG/bin" "$STAGE/opt/$PKG/share/doc/$PKG" "$STAGE/usr/bin"
install -m 755 "$OUT/$PKG" "$STAGE/opt/$PKG/bin/$PKG"
ln -s "../../opt/$PKG/bin/$PKG" "$STAGE/usr/bin/$PKG"
install -m 644 "$PROJ/apps/$PKG/$PKG.c" "$STAGE/opt/$PKG/share/doc/$PKG/$PKG.c"
install -m 644 "$FFSRC/COPYING.LGPLv2.1" "$STAGE/opt/$PKG/share/doc/$PKG/COPYING.LGPLv2.1"
cat > "$STAGE/opt/$PKG/share/doc/$PKG/NOTICE" <<N
nplay $VERSION is linked statically with the libraries of ffmpeg $FFVERSION (https://ffmpeg.org/), built without GPL parts and without external
libraries: LGPL version 2.1 or later (COPYING.LGPLv2.1). The sources of ffmpeg are on https://ffmpeg.org/releases/ffmpeg-$FFVERSION.tar.xz and the
build recipe is apps/ffmpeg/build.sh of https://github.com/n900-resurrection/N900. The source of nplay itself (nplay.c) is in this directory.
N

SECTION=user/multimedia
DEPENDS="libc6 (>= 2.5), libsdl1.2"
DISPLAY_NAME="nplay"
SHORT_DESC="Video player with ffmpeg: 360p H.264 and AAC, no conversion"
LONG_DESC="nplay $VERSION, a small video player for the N900 built on the libraries of ffmpeg 9 (with NEON) and SDL. It plays the
H.264/AAC (MP4, fragmented MP4, Matroska/WebM) files that the old Media Player of the phone cannot: 240p smoothly, 360p mostly.
It can play the picture and the sound from two separate files (the way video sites deliver them) without joining them, uses the
hardware overlay of the phone, keeps the picture in step with the sound (dropping frames, then simplifying the decoding when the phone
cannot keep up) and uses and changes the volume of the phone (Up/Down and a slider), shows its controls with a tap on the picture like the player of the phone (a seek bar with the times, play/pause, 10 s back/forward) and Backspace quits.
Usage: nplay [-n] [-N] [-s SECONDS] [-f] [-v] VIDEO [AUDIO]. Esc quits, space pauses."
debpack_build
