#!/bin/bash
# Cross-build Abuse (the 1996 run-and-gun by Crack dot Com; the SDL 2 port of Xenoveritas, public domain / GPL-2.0, data included) for Maemo 5. Run INSIDE the Workshop:
#   workshop exec n900 -- bash -c 'VERSION=0.9.1 /project/apps/abuse/build.sh'   (or: make -C apps/abuse build)
# Output: /project/build/out/abuse-$VERSION/root/opt/abuse/{bin/abuse,share/games/abuse}
#
# NOT TRIED YET (prepared 2026-11-23 to be built on the desktop): expect to fix small things (a missing #include, a cmake option); write what you change into the README.
# SDL 2 and SDL2_mixer of apps/sdl2, apps/sdl2-mixer (shared, /opt/sdl2/lib). The game data (art, sound, levels of the shareware/registered game) is in the tarball.
set -euo pipefail

VERSION="${VERSION:-0.9.1}"
PROJ=/project
SR="$PROJ/sysroot"
DL="$PROJ/build/downloads"
SRCDIR="$PROJ/build/src"
OBJ="$PROJ/build/obj/abuse-$VERSION"
OUT="$PROJ/build/out/abuse-$VERSION"
. "$PROJ/apps/sdl2/sdl2-env.sh"
. "$PROJ/apps/sdl2/sdl2-cmake.sh"
[ -f "$MIXROOT/lib/libSDL2_mixer.so" ] || { echo "Missing SDL2_mixer, run: make sdl2-mixer"; exit 1; }

mkdir -p "$DL" "$SRCDIR"
f="abuse-$VERSION.tar.gz"
[ -s "$DL/$f" ] || curl -fL --retry 3 -o "$DL/$f" "https://github.com/Xenoveritas/abuse/archive/refs/tags/v$VERSION.tar.gz"
echo "sha256 $(sha256sum "$DL/$f" | cut -d' ' -f1)  $f"
rm -rf "$SRCDIR/abuse-$VERSION" "$OBJ" "$OUT"
mkdir -p "$SRCDIR/abuse-$VERSION" "$OBJ" "$OUT/root"
tar -C "$SRCDIR/abuse-$VERSION" --strip-components=1 -xzf "$DL/$f"
sdl2_cmake_setup
cd "$OBJ"
cmake -G "Unix Makefiles" -DCMAKE_TOOLCHAIN_FILE="$OBJ/toolchain.cmake" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/opt/abuse \
    "${CMAKE_SDL_ARGS[@]}" "$SRCDIR/abuse-$VERSION" > "$OUT/configure.log" 2>&1 || { tail -30 "$OUT/configure.log"; exit 1; }
make -j"$(nproc)" > "$OUT/make.log" 2>&1 || { grep -E 'error|Error' "$OUT/make.log" | head -20; tail -15 "$OUT/make.log"; exit 1; }
make DESTDIR="$OUT/root" install > "$OUT/install.log" 2>&1 || { tail -15 "$OUT/install.log"; exit 1; }
ROOT="$OUT/root/opt/abuse"
arm-linux-gnueabi-strip --strip-unneeded "$ROOT"/bin/*
cp "$SRCDIR/abuse-$VERSION/COPYING" "$OUT/COPYING"
echo "== Check"
find "$ROOT" -maxdepth 3 -type d | sed "s|$OUT/root||" | head
file "$ROOT/bin/abuse" | cut -c1-140
arm-linux-gnueabi-readelf -d "$ROOT/bin/abuse" | grep -E "NEEDED|RPATH|RUNPATH"
echo -n "Highest glibc symbol: "
arm-linux-gnueabi-objdump -T "$ROOT"/bin/abuse | grep -oE 'GLIBC_[0-9.]+' | sort -uV | tail -1
ls -l "$ROOT"/bin/*; du -sh "$ROOT/share"
