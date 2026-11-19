#!/bin/bash
# Cross-build a minimal ffmpeg for Maemo 5 (armel, glibc 2.5, Cortex-A8 with NEON). Run INSIDE the Workshop:
#   workshop exec n900 -- bash -c 'VERSION=9.0.2 /project/apps/ffmpeg/build.sh'   (or: make -C apps/ffmpeg build)
# Output: /project/build/out/ffmpeg-$VERSION/ffmpeg  (stripped, static, no external libraries)
#         /project/build/out/ffmpeg-$VERSION/root/opt/ffmpeg/{include,lib}  (the static libav* libraries: apps/nplay links them)
# Only what a YouTube client needs: MP4/Matroska/WebM input, H.264/AAC/MPEG-4/VP8/Opus decoding, MP4/NUT/raw output.
set -euo pipefail

VERSION="${VERSION:-9.0.2}"
PROJ=/project
SR="$PROJ/sysroot"
DL="$PROJ/build/downloads"
SRCDIR="$PROJ/build/src"
OUT="$PROJ/build/out/ffmpeg-$VERSION"
OBJ="$PROJ/build/obj/ffmpeg-$VERSION"

[ -d "$SR/usr/include" ] || { echo "Missing sysroot, run: make sysroot"; exit 1; }
mkdir -p "$DL" "$SRCDIR"
f="ffmpeg-$VERSION.tar.xz"
[ -s "$DL/$f" ] || curl -fL --retry 3 -o "$DL/$f" "https://ffmpeg.org/releases/$f"
echo "sha256 $(sha256sum "$DL/$f" | cut -d' ' -f1)  $f"
rm -rf "$SRCDIR/ffmpeg-$VERSION" "$OBJ" "$OUT"
tar -C "$SRCDIR" -xJf "$DL/$f"
mkdir -p "$OBJ" "$OUT"
cd "$OBJ"

# --disable-everything and then only the needed parts; --disable-network: no sockets (the app downloads with curl).
"$SRCDIR/ffmpeg-$VERSION/configure" \
    --enable-cross-compile --arch=arm --cpu=cortex-a8 --target-os=linux \
    --cross-prefix=arm-linux-gnueabi- --cc="$PROJ/scripts/maemo-gcc" --sysroot="$SR" \
    --prefix=/opt/ffmpeg --enable-neon --enable-static --disable-shared --disable-debug --disable-doc \
    --disable-everything --disable-network --disable-autodetect --disable-ffplay --disable-ffprobe \
    --enable-protocol=file,pipe \
    --enable-demuxer=mov,matroska,mp3,ogg,aac,rawvideo \
    --enable-muxer=mp4,nut,rawvideo,pcm_s16le,null \
    --enable-parser=h264,aac,mpeg4video,vp8,opus \
    --enable-decoder=h264,aac,mpeg4,vp8,opus,mp3,rawvideo,pcm_s16le \
    --enable-bsf=aac_adtstoasc,h264_mp4toannexb \
    --enable-filter=scale,aresample,format,aformat,null,anull \
    --enable-encoder=rawvideo,pcm_s16le,mpeg4 \
    --extra-cflags="-O2 -Dstatic_assert=_Static_assert -include $PROJ/scripts/maemo-compat.h" --extra-libs="-lm -lpthread -lrt" \
    > "$OUT/configure.log" 2>&1 || { tail -30 "$OUT/configure.log"; exit 1; }
make -j"$(nproc)" ffmpeg > "$OUT/make.log" 2>&1 || { grep -E 'error|Error' "$OUT/make.log" | head -20; exit 1; }
make install DESTDIR="$OUT/root" > "$OUT/install.log" 2>&1 || { tail -20 "$OUT/install.log"; exit 1; }
arm-linux-gnueabi-strip -o "$OUT/ffmpeg" ffmpeg

echo "== Check"
file "$OUT/ffmpeg" | cut -c1-140
ls -l "$OUT/ffmpeg"
