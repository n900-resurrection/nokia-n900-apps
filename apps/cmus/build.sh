#!/bin/bash
# Cross-build cmus (music player for the terminal) for Maemo 5 (armel, glibc 2.5). Run INSIDE the Workshop: make -C apps/cmus build
# Needs the ffmpeg of this project (make -C apps/ffmpeg build: it is linked statically into the input plugin ip/ffmpeg.so, which plays mp3, aac/m4a,
# opus, ogg vorbis, flac, alac, ape and wav) and the sysroot.
#  - Output: PulseAudio only (the phone has libpulse 0.9.15 and no headers: the headers come from the pulseaudio 0.9.15 sources, build/deps/pulse-0.9.15).
#  - ncursesw 5.7 of the sysroot is linked statically (the phone has only plain libncurses5), as for nano.
#  - pkg-config files are written here: the real ones belong to the build computer (PKG_CONFIG_LIBDIR keeps them out).
# Output: /project/build/out/cmus-$VERSION/root/opt/cmus/{bin,lib/cmus,share}
set -euo pipefail

VERSION="${VERSION:-2.13.0}"
PROJ=/project
SR="$PROJ/sysroot"
DL="$PROJ/build/downloads"
SRCDIR="$PROJ/build/src"
OUT="$PROJ/build/out/cmus-$VERSION"
OBJ="$PROJ/build/obj/cmus-$VERSION"
FF="$PROJ/build/out/ffmpeg-9.0.2/root/opt/ffmpeg"
PA="$PROJ/build/deps/pulse-0.9.15"
PC="$OBJ/pc"

[ -d "$SR/usr/include" ] || { echo "Missing sysroot, run: make sysroot"; exit 1; }
[ -f "$FF/lib/libavformat.a" ] || { echo "Missing ffmpeg, run: make -C apps/ffmpeg build"; exit 1; }
mkdir -p "$DL" "$SRCDIR"
f="cmus-v$VERSION.tar.gz"
[ -s "$DL/$f" ] || curl -fL --retry 3 -o "$DL/$f" "https://github.com/cmus/cmus/archive/refs/tags/v$VERSION.tar.gz"
echo "sha256 $(sha256sum "$DL/$f" | cut -d' ' -f1)  $f"

# the PulseAudio headers (the phone's libpulse.so.0 is 0.9.15; version.h is generated at configure time upstream)
if [ ! -f "$PA/include/pulse/pulseaudio.h" ]; then
    p="pulseaudio-0.9.15.tar.gz"
    [ -s "$DL/$p" ] || curl -fL --retry 3 -o "$DL/$p" "https://freedesktop.org/software/pulseaudio/releases/$p"
    echo "1e8ad5b7c5cf3485bd0738c296274ff2c99d26d12a25a225dc250eddea25b9f1  $DL/$p" | sha256sum -c -
    rm -rf "$PA"; mkdir -p "$PA/include/pulse" "$PA/lib"
    tar -C "$PA" -xzf "$DL/$p" --strip-components=3 --wildcards 'pulseaudio-0.9.15/src/pulse/*.h' 'pulseaudio-0.9.15/src/pulse/version.h.in'
    mv "$PA"/*.h "$PA/include/pulse/"
    sed -e 's/@PACKAGE_VERSION@/0.9.15/; s/@PA_API_VERSION@/11/; s/@PA_PROTOCOL_VERSION@/16/; s/@PA_MAJOR@/0/; s/@PA_MINOR@/9/; s/@PA_MICRO@/15/' \
        "$PA/version.h.in" > "$PA/include/pulse/version.h"
    rm -f "$PA/version.h.in"
    ln -s "$SR/usr/lib/libpulse.so.0" "$PA/lib/libpulse.so"
fi

rm -rf "$SRCDIR/cmus-$VERSION" "$OBJ" "$OUT"
mkdir -p "$SRCDIR/cmus-$VERSION" "$OBJ" "$PC" "$OUT/root"
tar -C "$SRCDIR/cmus-$VERSION" -xzf "$DL/$f" --strip-components=1

# pkg-config files for the libraries of the target
cat > "$PC/ncursesw.pc" <<EOT
Name: ncursesw
Description: ncursesw 5.7 of the sysroot, static
Version: 5.7
Cflags: -I$SR/usr/include/ncursesw -I$SR/usr/include
Libs: -L$SR/usr/lib -Wl,-Bstatic -lncursesw -Wl,-Bdynamic
EOT
cat > "$PC/libpulse.pc" <<EOT
Name: libpulse
Description: PulseAudio client library 0.9.15 (headers of the 0.9.15 sources, the library of the sysroot)
Version: 0.9.15
Cflags: -I$PA/include
Libs: -L$PA/lib -lpulse
EOT
# -lrt: clock_gettime of glibc 2.5 is in librt, and the plugin is loaded with RTLD_NOW (an undefined symbol makes it fail); -latomic is not in the sysroot
for l in libavformat libavcodec libavutil libswresample; do
    sed -e "s#^prefix=.*#prefix=$FF#; s#^libdir=.*#libdir=$FF/lib#; s#^includedir=.*#includedir=$FF/include#" \
        -e 's/ -latomic//' -e 's/^Libs:\(.*\)$/Libs:\1 -lrt/' \
        "$FF/lib/pkgconfig/$l.pc" > "$PC/$l.pc"
done
export PKG_CONFIG_LIBDIR="$PC" PKG_CONFIG_PATH=""

# cmus builds in its source tree
cd "$SRCDIR/cmus-$VERSION"
# libpulse >= 0.9.19 is asked for; the functions cmus uses are in 0.9.15 (the compiler below finds out if one is not)
sed -i 's/libpulse >= 0.9.19/libpulse >= 0.9.15/' configure
# libpulse 0.9.15 lacks four names that op/pulse.c uses: a small header supplies them (apps/cmus/pulse-compat.h)
cp "$PROJ/apps/cmus/pulse-compat.h" op/pulse-compat.h
sed -i '0,/#include <pulse\/pulseaudio.h>/s//#include <pulse\/pulseaudio.h>\n#include "pulse-compat.h"/' op/pulse.c
grep -q pulse-compat op/pulse.c || { echo "cannot patch op/pulse.c"; exit 1; }
./configure prefix=/opt/cmus ${CMUS_CONFIGURE_EXTRA:-} \
    CC="$PROJ/scripts/maemo-gcc" HOSTCC=gcc \
    CFLAGS="-Os -include $PROJ/scripts/maemo-compat.h" \
    > "$OUT/configure.log" 2>&1 || { tail -40 "$OUT/configure.log"; exit 1; }
grep -E "ffmpeg|PULSE|NCURSES" "$OUT/configure.log" | cut -c1-160 || true
make -j"$(nproc)" VERSION="v$VERSION" > "$OUT/make.log" 2>&1 || { grep -E 'error|Error|undefined' "$OUT/make.log" | head -30; exit 1; }
make install VERSION="v$VERSION" DESTDIR="$OUT/root" STRIP=arm-linux-gnueabi-strip > "$OUT/install.log" 2>&1 || { tail -20 "$OUT/install.log"; exit 1; }
find "$OUT/root" -type f \( -name cmus -o -name cmus-remote -o -name '*.so' \) -exec arm-linux-gnueabi-strip {} +

echo "== Check"
find "$OUT/root/opt/cmus" -type f | head -40
file "$OUT/root/opt/cmus/bin/cmus" | cut -c1-140
