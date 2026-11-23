#!/bin/bash
# Package SDL2_mixer as a .deb for Maemo 5. Run INSIDE the Workshop after build.sh: make -C apps/sdl2-mixer deb
# Output: /project/build/deb/libsdl2-mixer_<VERSION>-<REV>_armel.deb   (the shared library in /opt/sdl2/lib; the headers stay in build/out for the builds of the games)
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=libsdl2-mixer
VERSION="${VERSION:-2.8.1}"
OUT="$PROJ/build/out/sdl2-mixer-$VERSION"
ROOT="$OUT/root/opt/sdl2"
STAGE="$PROJ/build/deb/stage-$PKG"
[ -f "$ROOT/lib/libSDL2_mixer-2.0.so.0" ] || { echo "Missing build output in $OUT, run build.sh first (make build)"; exit 1; }

rm -rf "$STAGE"; mkdir -p "$STAGE/opt/sdl2/lib" "$STAGE/opt/sdl2/share/doc/$PKG"
cp -a "$ROOT"/lib/libSDL2_mixer-2.0.so.0 "$ROOT"/lib/libSDL2_mixer-2.0.so.0.* "$STAGE/opt/sdl2/lib/"
install -m 644 "$OUT/LICENSE.txt" "$STAGE/opt/sdl2/share/doc/$PKG/LICENSE.txt"

SECTION=user/development
DEPENDS="libc6 (>= 2.5), libsdl2 (>= 2.30)"
DISPLAY_NAME="SDL2_mixer"
SHORT_DESC="SDL2_mixer $VERSION: sound and music for SDL 2 games (WAV, Ogg, MP3, FLAC)"
LONG_DESC="SDL2_mixer $VERSION for Maemo 5, in /opt/sdl2/lib next to libsdl2. WAV, AIFF and VOC, Ogg Vorbis (stb_vorbis), MP3 (minimp3) and FLAC (dr_flac) are decoded by code built into the library, so no other library is needed. MOD, MIDI, Opus and WavPack are not built.
Upstream: https://github.com/libsdl-org/SDL_mixer"
MAINTAINER="elPytel (build of upstream SDL_mixer by Sam Lantinga and contributors)"
debpack_build
