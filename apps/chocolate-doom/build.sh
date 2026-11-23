#!/bin/bash
# Cross-build Chocolate Doom 3.1.1 (the faithful Doom, Heretic, Hexen and Strife source port, GPL-2.0; SDL 2) for Maemo 5. Run INSIDE the Workshop:
#   workshop exec n900 -- bash -c 'VERSION=3.1.1 /project/apps/chocolate-doom/build.sh'   (or: make -C apps/chocolate-doom build)
# Output: /project/build/out/chocolate-doom-$VERSION/root/opt/chocolate-doom/{bin,share}
#
# NOT TRIED YET (prepared 2026-11-23 to be built on the desktop): expect to fix small things (a cmake option, the documentation step needs python3);
# write what you change into the README.
# Without SDL2_net (no network games), FluidSynth, libsamplerate, libpng. Music: SDL2_mixer of apps/sdl2-mixer has no MIDI decoder, so the music is silent until
# a MIDI back end (timidity with a sound font, or fluidsynth) is added to it; the sound effects work. The game data (an IWAD such as freedoom1.wad) is not in the package.
set -euo pipefail

VERSION="${VERSION:-3.1.1}"
PROJ=/project
SR="$PROJ/sysroot"
DL="$PROJ/build/downloads"
SRCDIR="$PROJ/build/src"
OBJ="$PROJ/build/obj/chocolate-doom-$VERSION"
OUT="$PROJ/build/out/chocolate-doom-$VERSION"
. "$PROJ/apps/sdl2/sdl2-env.sh"
. "$PROJ/apps/sdl2/sdl2-cmake.sh"
[ -f "$MIXROOT/lib/libSDL2_mixer.so" ] || { echo "Missing SDL2_mixer, run: make sdl2-mixer"; exit 1; }

mkdir -p "$DL" "$SRCDIR"
f="chocolate-doom-$VERSION.tar.gz"
[ -s "$DL/$f" ] || curl -fL --retry 3 -o "$DL/$f" "https://github.com/chocolate-doom/chocolate-doom/archive/refs/tags/chocolate-doom-$VERSION.tar.gz"
echo "sha256 $(sha256sum "$DL/$f" | cut -d' ' -f1)  $f"
rm -rf "$SRCDIR/chocolate-doom-$VERSION" "$OBJ" "$OUT"
mkdir -p "$SRCDIR/chocolate-doom-$VERSION" "$OBJ" "$OUT/root"
tar -C "$SRCDIR/chocolate-doom-$VERSION" --strip-components=1 -xzf "$DL/$f"
sdl2_cmake_setup
cd "$OBJ"
cmake -G "Unix Makefiles" -DCMAKE_TOOLCHAIN_FILE="$OBJ/toolchain.cmake" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/opt/chocolate-doom \
    -DENABLE_SDL2_NET=OFF -DCMAKE_DISABLE_FIND_PACKAGE_FluidSynth=ON -DCMAKE_DISABLE_FIND_PACKAGE_SampleRate=ON -DCMAKE_DISABLE_FIND_PACKAGE_PNG=ON \
    "${CMAKE_SDL_ARGS[@]}" "$SRCDIR/chocolate-doom-$VERSION" > "$OUT/configure.log" 2>&1 || { tail -30 "$OUT/configure.log"; exit 1; }
make -j"$(nproc)" > "$OUT/make.log" 2>&1 || { grep -E 'error|Error' "$OUT/make.log" | head -20; tail -15 "$OUT/make.log"; exit 1; }
make DESTDIR="$OUT/root" install > "$OUT/install.log" 2>&1 || { tail -15 "$OUT/install.log"; exit 1; }
ROOT="$OUT/root/opt/chocolate-doom"
for b in "$ROOT"/bin/*; do arm-linux-gnueabi-strip --strip-unneeded "$b"; done
cp "$SRCDIR/chocolate-doom-$VERSION/COPYING.md" "$OUT/COPYING.md"
echo "== Check"
find "$ROOT" -maxdepth 3 -type d | sed "s|$OUT/root||" | head
ls "$ROOT/bin"
file "$ROOT/bin/chocolate-doom" | cut -c1-140
arm-linux-gnueabi-readelf -d "$ROOT/bin/chocolate-doom" | grep -E "NEEDED|RPATH|RUNPATH"
echo -n "Highest glibc symbol: "
arm-linux-gnueabi-objdump -T "$ROOT"/bin/chocolate-doom | grep -oE 'GLIBC_[0-9.]+' | sort -uV | tail -1
du -sh "$ROOT"
