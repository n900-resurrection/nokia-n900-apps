#!/bin/bash
# Package SDL2_ttf as a .deb for Maemo 5. Run INSIDE the Workshop after build.sh: make -C apps/sdl2-ttf deb
# Output: /project/build/deb/libsdl2-ttf_<VERSION>-<REV>_armel.deb   (the shared library in /opt/sdl2/lib; the headers stay in build/out for the builds of the games)
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=libsdl2-ttf
VERSION="${VERSION:-2.24.0}"
OUT="$PROJ/build/out/sdl2-ttf-$VERSION"
ROOT="$OUT/root/opt/sdl2"
STAGE="$PROJ/build/deb/stage-$PKG"
[ -f "$ROOT/lib/libSDL2_ttf-2.0.so.0" ] || { echo "Missing build output in $OUT, run build.sh first (make build)"; exit 1; }

rm -rf "$STAGE"; mkdir -p "$STAGE/opt/sdl2/lib" "$STAGE/opt/sdl2/share/doc/$PKG"
cp -a "$ROOT"/lib/libSDL2_ttf-2.0.so.0 "$ROOT"/lib/libSDL2_ttf-2.0.so.0.* "$STAGE/opt/sdl2/lib/"
install -m 644 "$OUT/LICENSE.txt" "$STAGE/opt/sdl2/share/doc/$PKG/LICENSE.txt"

SECTION=user/development
DEPENDS="libc6 (>= 2.5), libsdl2 (>= 2.30)"
DISPLAY_NAME="SDL2_ttf"
SHORT_DESC="SDL2_ttf $VERSION: TrueType fonts for SDL 2 games"
LONG_DESC="SDL2_ttf $VERSION for Maemo 5, in /opt/sdl2/lib next to libsdl2. TrueType and OpenType fonts are rendered by the FreeType built into the library (the system FreeType 2.3.9 is too old); HarfBuzz is not used, so complex scripts are not shaped.
Upstream: https://github.com/libsdl-org/SDL_ttf"
MAINTAINER="elPytel (build of upstream SDL_ttf by Sam Lantinga and contributors)"
debpack_build
