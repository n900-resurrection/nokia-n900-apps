#!/bin/bash
# Package SDL2_image as a .deb for Maemo 5. Run INSIDE the Workshop after build.sh: make -C apps/sdl2-image deb
# Output: /project/build/deb/libsdl2-image_<VERSION>-<REV>_armel.deb   (the shared library in /opt/sdl2/lib; the headers stay in build/out for the builds of the games)
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=libsdl2-image
VERSION="${VERSION:-2.8.8}"
OUT="$PROJ/build/out/sdl2-image-$VERSION"
ROOT="$OUT/root/opt/sdl2"
STAGE="$PROJ/build/deb/stage-$PKG"
[ -f "$ROOT/lib/libSDL2_image-2.0.so.0" ] || { echo "Missing build output in $OUT, run build.sh first (make build)"; exit 1; }

rm -rf "$STAGE"; mkdir -p "$STAGE/opt/sdl2/lib" "$STAGE/opt/sdl2/share/doc/$PKG"
cp -a "$ROOT"/lib/libSDL2_image-2.0.so.0 "$ROOT"/lib/libSDL2_image-2.0.so.0.* "$STAGE/opt/sdl2/lib/"
install -m 644 "$OUT/LICENSE.txt" "$STAGE/opt/sdl2/share/doc/$PKG/LICENSE.txt"

SECTION=user/development
DEPENDS="libc6 (>= 2.5), libsdl2 (>= 2.30)"
DISPLAY_NAME="SDL2_image"
SHORT_DESC="SDL2_image $VERSION: image loading for SDL 2 games (PNG, JPEG, GIF, BMP, XPM, ...)"
LONG_DESC="SDL2_image $VERSION for Maemo 5, in /opt/sdl2/lib next to libsdl2. PNG and JPEG are decoded by the built-in stb_image (no libpng or libjpeg needed), plus GIF, BMP, XPM, LBM, QOI and XCF. TIFF, WebP, AVIF, JPEG XL and SVG are not built.
Upstream: https://github.com/libsdl-org/SDL_image"
MAINTAINER="elPytel (build of upstream SDL_image by Sam Lantinga and contributors)"
debpack_build
