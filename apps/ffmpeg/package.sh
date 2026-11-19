#!/bin/bash
# Package the built ffmpeg as a .deb for Maemo 5. Run INSIDE the Workshop after build.sh: make -C apps/ffmpeg deb
# Output: /project/build/deb/ffmpeg_<VERSION>-<REV>_armel.deb
# Only the command-line program is shipped (static, no shared libraries); the static libav* libraries for building other programs
# (apps/nplay) stay in build/out/ffmpeg-<VERSION>/root/opt/ffmpeg.
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=ffmpeg
VERSION="${VERSION:-9.0.2}"
OUT="$PROJ/build/out/$PKG-$VERSION"
SRC="$PROJ/build/src/$PKG-$VERSION"
STAGE="$PROJ/build/deb/stage-$PKG"
[ -x "$OUT/$PKG" ] || { echo "Missing $OUT/$PKG, run build.sh first (make build)"; exit 1; }

rm -rf "$STAGE"
mkdir -p "$STAGE/opt/$PKG/bin" "$STAGE/opt/$PKG/share/doc/$PKG" "$STAGE/usr/bin"
install -m 755 "$OUT/$PKG" "$STAGE/opt/$PKG/bin/$PKG"
ln -s "../../opt/$PKG/bin/$PKG" "$STAGE/usr/bin/$PKG"
install -m 644 "$SRC/COPYING.LGPLv2.1" "$STAGE/opt/$PKG/share/doc/$PKG/COPYING.LGPLv2.1"
cat > "$STAGE/opt/$PKG/share/doc/$PKG/NOTICE" <<N
ffmpeg $VERSION, https://ffmpeg.org/, built without GPL parts and without external libraries: LGPL version 2.1 or later
(see COPYING.LGPLv2.1). The sources are on https://ffmpeg.org/releases/ffmpeg-$VERSION.tar.xz; the build recipe is
apps/ffmpeg/build.sh of https://github.com/n900-resurrection/N900 (the configure options are in it).
N

SECTION=user/multimedia
DEPENDS="libc6 (>= 2.5)"
DISPLAY_NAME="ffmpeg"
SHORT_DESC="ffmpeg: remux and decode MP4/Matroska, H.264 and AAC (NEON)"
LONG_DESC="ffmpeg $VERSION built for Maemo 5 (armel, glibc 2.5, NEON), a minimal static build: MP4, Matroska/WebM, MP3,
Ogg and AAC input; H.264, MPEG-4, VP8, AAC, Opus and MP3 decoding; MP4, NUT and raw output. No network protocols
(files and pipes only). It is much faster than the old codecs of the phone: 360p H.264 at about 39 frames per second.
Used for example to turn the fragmented MP4 files of video sites into plain MP4 (ffmpeg -i video.mp4 -i audio.mp4 -c copy out.mp4).
Upstream: https://ffmpeg.org/"
debpack_build
