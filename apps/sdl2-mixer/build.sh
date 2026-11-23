#!/bin/bash
# Cross-build SDL2_mixer 2.8.1 for Maemo 5 (armel, glibc 2.5) on the SDL 2 of apps/sdl2. Run INSIDE the Workshop:
#   workshop exec n900 -- bash -c 'VERSION=2.8.1 /project/apps/sdl2-mixer/build.sh'   (or: make -C apps/sdl2-mixer build)
# Output: /project/build/out/sdl2-mixer-$VERSION/root/opt/sdl2/{lib,include} (the shared library stripped; the headers are for building games).
# Sound: WAV/AIFF/VOC, Ogg Vorbis (stb_vorbis), MP3 (minimp3), FLAC (dr_flac): all code is in the tarball, no external library.
# Not built: MOD, MIDI (timidity needs a sound font or patch set), Opus, WavPack (they need libraries or data).
set -euo pipefail

VERSION="${VERSION:-2.8.1}"
PROJ=/project
SR="$PROJ/sysroot"
DL="$PROJ/build/downloads"
SRCDIR="$PROJ/build/src"
OBJ="$PROJ/build/obj/sdl2-mixer-$VERSION"
OUT="$PROJ/build/out/sdl2-mixer-$VERSION"
. "$PROJ/apps/sdl2/sdl2-env.sh"

mkdir -p "$DL" "$SRCDIR"
f="SDL2_mixer-$VERSION.tar.gz"
[ -s "$DL/$f" ] || curl -fL --retry 3 -o "$DL/$f" "https://github.com/libsdl-org/SDL_mixer/releases/download/release-$VERSION/$f"
echo "sha256 $(sha256sum "$DL/$f" | cut -d' ' -f1)  $f"
rm -rf "$SRCDIR/SDL2_mixer-$VERSION" "$OBJ" "$OUT"
tar -C "$SRCDIR" -xzf "$DL/$f"
mkdir -p "$OBJ" "$OUT/root"
cd "$OBJ"

CC="$PROJ/scripts/maemo-gcc -include $PROJ/scripts/maemo-compat.h" CFLAGS="-O2 -fPIC" LDFLAGS="-Wl,-rpath,/opt/sdl2/lib" \
"$SRCDIR/SDL2_mixer-$VERSION/configure" --host=arm-linux-gnueabi --prefix=/opt/sdl2 --enable-shared --enable-static \
    --disable-music-mod --disable-music-midi --disable-music-opus --disable-music-wavpack --disable-music-gme \
    --disable-music-ogg-vorbis --disable-music-ogg-tremor --disable-music-flac-libflac --disable-music-mp3-mpg123 \
    --enable-music-ogg-stb --enable-music-mp3-minimp3 --enable-music-flac-drflac \
    > "$OUT/configure.log" 2>&1 || { tail -30 "$OUT/configure.log"; exit 1; }
make -j"$(nproc)" > "$OUT/make.log" 2>&1 || { grep -E 'error|Error' "$OUT/make.log" | head -20; tail -15 "$OUT/make.log"; exit 1; }
make DESTDIR="$OUT/root" install > "$OUT/install.log" 2>&1 || { tail -15 "$OUT/install.log"; exit 1; }
ROOT="$OUT/root/opt/sdl2"
arm-linux-gnueabi-strip --strip-unneeded "$ROOT"/lib/libSDL2_mixer-2.0.so.0.*
cp "$SRCDIR/SDL2_mixer-$VERSION/LICENSE.txt" "$OUT/LICENSE.txt"
echo "== Check"
arm-linux-gnueabi-readelf -d "$ROOT"/lib/libSDL2_mixer-2.0.so.0.* | grep NEEDED
echo -n "Highest glibc symbol: "
arm-linux-gnueabi-objdump -T "$ROOT"/lib/libSDL2_mixer-2.0.so.0.* | grep -oE 'GLIBC_[0-9.]+' | sort -uV | tail -1
ls -l "$ROOT"/lib/libSDL2_mixer-2.0.so.0.*
