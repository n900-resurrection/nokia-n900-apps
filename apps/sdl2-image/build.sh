#!/bin/bash
# Cross-build SDL2_image 2.8.8 for Maemo 5 (armel, glibc 2.5) on the SDL 2 of apps/sdl2. Run INSIDE the Workshop:
#   workshop exec n900 -- bash -c 'VERSION=2.8.8 /project/apps/sdl2-image/build.sh'   (or: make -C apps/sdl2-image build)
# Output: /project/build/out/sdl2-image-$VERSION/root/opt/sdl2/{lib,include} (the shared library stripped; the headers are for building games).
# Images: PNG and JPEG through stb_image (no libpng/libjpeg), GIF, BMP, XPM, LBM, QOI, XCF; no TIFF, WebP, AVIF, JXL, SVG (they need libraries).
set -euo pipefail

VERSION="${VERSION:-2.8.8}"
PROJ=/project
SR="$PROJ/sysroot"
DL="$PROJ/build/downloads"
SRCDIR="$PROJ/build/src"
OBJ="$PROJ/build/obj/sdl2-image-$VERSION"
OUT="$PROJ/build/out/sdl2-image-$VERSION"
. "$PROJ/apps/sdl2/sdl2-env.sh"

mkdir -p "$DL" "$SRCDIR"
f="SDL2_image-$VERSION.tar.gz"
[ -s "$DL/$f" ] || curl -fL --retry 3 -o "$DL/$f" "https://github.com/libsdl-org/SDL_image/releases/download/release-$VERSION/$f"
echo "sha256 $(sha256sum "$DL/$f" | cut -d' ' -f1)  $f"
rm -rf "$SRCDIR/SDL2_image-$VERSION" "$OBJ" "$OUT"
tar -C "$SRCDIR" -xzf "$DL/$f"
mkdir -p "$OBJ" "$OUT/root"
cd "$OBJ"

CC="$PROJ/scripts/maemo-gcc -include $PROJ/scripts/maemo-compat.h" CFLAGS="-O2 -fPIC" LDFLAGS="-Wl,-rpath,/opt/sdl2/lib" \
"$SRCDIR/SDL2_image-$VERSION/configure" --host=arm-linux-gnueabi --prefix=/opt/sdl2 --enable-shared --enable-static \
    --enable-stb-image --disable-avif --disable-jxl --disable-tif --disable-webp --disable-svg --disable-save-jpg --disable-save-png \
    > "$OUT/configure.log" 2>&1 || { tail -30 "$OUT/configure.log"; exit 1; }
make -j"$(nproc)" > "$OUT/make.log" 2>&1 || { grep -E 'error|Error' "$OUT/make.log" | head -20; tail -15 "$OUT/make.log"; exit 1; }
make DESTDIR="$OUT/root" install > "$OUT/install.log" 2>&1 || { tail -15 "$OUT/install.log"; exit 1; }
ROOT="$OUT/root/opt/sdl2"
arm-linux-gnueabi-strip --strip-unneeded "$ROOT"/lib/libSDL2_image-2.0.so.0.*
cp "$SRCDIR/SDL2_image-$VERSION/LICENSE.txt" "$OUT/LICENSE.txt"
echo "== Check"
arm-linux-gnueabi-readelf -d "$ROOT"/lib/libSDL2_image-2.0.so.0.* | grep NEEDED
echo -n "Highest glibc symbol: "
arm-linux-gnueabi-objdump -T "$ROOT"/lib/libSDL2_image-2.0.so.0.* | grep -oE 'GLIBC_[0-9.]+' | sort -uV | tail -1
ls -l "$ROOT"/lib/libSDL2_image-2.0.so.0.*
