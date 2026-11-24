#!/bin/bash
# Cross-build DevilutionX 1.5.5 (Diablo 1 engine, SDL 2; the game data DIABDAT.MPQ or the shareware spawn.mpq comes from the player) for Maemo 5. Run INSIDE the Workshop:
#   workshop exec n900 -- bash -c 'VERSION=1.5.5 /project/apps/devilutionx/build.sh'   (or: make -C apps/devilutionx build)
# Output: /project/build/out/devilutionx-$VERSION/root/opt/devilutionx/{bin/devilutionx,share}
#
# NOT TRIED YET (prepared 2026-11-23 to be built on the desktop): the biggest of the prepared ports, expect work. Known risks: C++20 against libstdc++ 13 with the glibc 2.5 shims
# (maemo-g++), the vendored dependencies (the tarball "fully-vendored" is used so that cmake needs no network), RAM and speed on the phone (256 MB, Cortex-A8: try
# the smaller window and the options in diablo.ini), SDL2_image (a dependency of this version: check).
# Switched off: network play (NONET: no ZeroTier, TCP, libsodium), tests, the discord SDK, the devilutionx.mpq archive (needs smpq: the assets stay as files).
# The libraries are those of apps/sdl2*, shared (/opt/sdl2/lib).
set -euo pipefail

VERSION="${VERSION:-1.5.5}"
PROJ=/project
SR="$PROJ/sysroot"
DL="$PROJ/build/downloads"
SRCDIR="$PROJ/build/src"
OBJ="$PROJ/build/obj/devilutionx-$VERSION"
OUT="$PROJ/build/out/devilutionx-$VERSION"
. "$PROJ/apps/sdl2/sdl2-env.sh"
. "$PROJ/apps/sdl2/sdl2-cmake.sh"
[ -f "$IMGROOT/lib/libSDL2_image.so" ] || { echo "Missing SDL2_image, run: make sdl2-image"; exit 1; }

mkdir -p "$DL" "$SRCDIR"
f="devilutionx-src-fully-vendored-$VERSION.tar.xz"
[ -s "$DL/$f" ] || curl -fL --retry 3 -o "$DL/$f" "https://github.com/diasurgical/devilutionX/releases/download/$VERSION/devilutionx-src-fully-vendored.tar.xz"
echo "sha256 $(sha256sum "$DL/$f" | cut -d' ' -f1)  $f"
rm -rf "$SRCDIR/devilutionx-$VERSION" "$OBJ" "$OUT"
mkdir -p "$SRCDIR/devilutionx-$VERSION" "$OBJ" "$OUT/root"
tar -C "$SRCDIR/devilutionx-$VERSION" --strip-components=1 -xJf "$DL/$f"
sdl2_cmake_setup
cd "$OBJ"
cmake -G "Unix Makefiles" -DCMAKE_TOOLCHAIN_FILE="$OBJ/toolchain.cmake" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/opt/devilutionx \
    -DCMAKE_STRIP=/usr/bin/arm-linux-gnueabi-strip -DDEVILUTIONX_SYSTEM_SDL2=ON -DDEVILUTIONX_STATIC_SDL2=OFF -DNONET=ON -DBUILD_TESTING=OFF -DDISCORD_INTEGRATION=OFF -DBUILD_ASSETS_MPQ=OFF -DDISABLE_LTO=ON \
    "${CMAKE_SDL_ARGS[@]}" "$SRCDIR/devilutionx-$VERSION" > "$OUT/configure.log" 2>&1 || { tail -30 "$OUT/configure.log"; exit 1; }
make -j"$(nproc)" > "$OUT/make.log" 2>&1 || { grep -E 'error|Error' "$OUT/make.log" | head -20; tail -15 "$OUT/make.log"; exit 1; }
make DESTDIR="$OUT/root" install > "$OUT/install.log" 2>&1 || { tail -15 "$OUT/install.log"; exit 1; }
ROOT="$OUT/root/opt/devilutionx"
for b in "$ROOT"/bin/*; do arm-linux-gnueabi-strip --strip-unneeded "$b"; done
cp "$SRCDIR/devilutionx-$VERSION/LICENSE.md" "$OUT/LICENSE.md"
echo "== Check"
find "$ROOT" -maxdepth 3 -type d | sed "s|$OUT/root||" | head
file "$ROOT/bin/devilutionx" | cut -c1-140
arm-linux-gnueabi-readelf -d "$ROOT/bin/devilutionx" | grep -E "NEEDED|RPATH|RUNPATH"
echo -n "Highest glibc symbol: "
arm-linux-gnueabi-objdump -T "$ROOT"/bin/devilutionx | grep -oE 'GLIBC_[0-9.]+' | sort -uV | tail -1
ls -l "$ROOT"/bin/*; du -sh "$ROOT"
