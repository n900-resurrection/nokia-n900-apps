#!/bin/bash
# Cross-build NXEngine-evo (Cave Story engine, SDL 2) for Maemo 5 (armel, glibc 2.5). Run INSIDE the Workshop:
#   workshop exec n900 -- bash -c 'VERSION=2.6.5-1 /project/apps/nxengine-evo/build.sh'   (or: make -C apps/nxengine-evo build)
# Output: /project/build/out/nxengine-evo-$VERSION/root/opt/nxengine-evo/{bin/nxengine-evo,bin/nxextract,share/nxengine/data}
#
# The sources are not changed (-include cstdint: some headers lack it, which GCC 13 no longer forgives). It links the shared SDL 2, SDL2_mixer and SDL2_image of apps/sdl2*, /opt/sdl2/lib (rpath), and libpng12 of the phone
# (libjpeg is only asked for at configure time). NON-portable install: the data directory is compiled in (/opt/nxengine-evo/share/nxengine/data/).
# The game data of Cave Story is not in the package: it is extracted from the freeware Doukutsu.exe by nxextract (see nxengine-evo-setup).
set -euo pipefail

VERSION="${VERSION:-2.6.5-1}"
PROJ=/project
SR="$PROJ/sysroot"
DL="$PROJ/build/downloads"
SRCDIR="$PROJ/build/src"
OBJ="$PROJ/build/obj/nxengine-evo-$VERSION"
OUT="$PROJ/build/out/nxengine-evo-$VERSION"
. "$PROJ/apps/sdl2/sdl2-env.sh"
MIX="$PROJ/build/out/sdl2-mixer-${SDL2_MIXER_VERSION:-2.8.1}/root/opt/sdl2"
IMG="$PROJ/build/out/sdl2-image-${SDL2_IMAGE_VERSION:-2.8.8}/root/opt/sdl2"
for d in "$MIX/lib/libSDL2_mixer.so" "$IMG/lib/libSDL2_image.so"; do [ -f "$d" ] || { echo "Missing $d, run: make sdl2-mixer sdl2-image"; exit 1; }; done
[ -f "$SR/usr/include/jpeglib.h" ] || { echo "Missing libjpeg headers in the sysroot, run: make sysroot"; exit 1; }
command -v cmake >/dev/null || { echo "Missing cmake in the workshop, run: make toolchain"; exit 1; }

mkdir -p "$DL" "$SRCDIR"
f="nxengine-evo-$VERSION.tar.gz"
[ -s "$DL/$f" ] || curl -fL --retry 3 -o "$DL/$f" "https://github.com/nxengine/nxengine-evo/archive/refs/tags/v$VERSION.tar.gz"
echo "sha256 $(sha256sum "$DL/$f" | cut -d' ' -f1)  $f"
rm -rf "$SRCDIR/nxengine-evo-$VERSION" "$OBJ" "$OUT"
tar -C "$SRCDIR" -xzf "$DL/$f"
mkdir -p "$OBJ" "$OUT/root"

cat > "$OBJ/toolchain.cmake" <<EOF
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR arm)
set(CMAKE_C_COMPILER $PROJ/scripts/maemo-gcc)
set(CMAKE_CXX_COMPILER $PROJ/scripts/maemo-g++)
set(CMAKE_C_FLAGS_INIT "-include $PROJ/scripts/maemo-compat.h -O2")
set(CMAKE_CXX_FLAGS_INIT "-O2 -include cstdint")
set(CMAKE_FIND_ROOT_PATH $SR)
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY BOTH)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE BOTH)
EOF
cd "$OBJ"
cmake -G "Unix Makefiles" -DCMAKE_TOOLCHAIN_FILE="$OBJ/toolchain.cmake" -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/opt/nxengine-evo -DPORTABLE=OFF \
    -DSDL2_INCLUDE_DIR="$SDLROOT/include/SDL2" -DSDL2_LIBRARY="$SDLROOT/lib/libSDL2.so" \
    -DSDL2_MIXER_INCLUDE_DIR="$MIX/include/SDL2" -DSDL2_MIXER_LIBRARY="$MIX/lib/libSDL2_mixer.so" \
    -DSDL2_IMAGE_INCLUDE_DIR="$IMG/include/SDL2" -DSDL2_IMAGE_LIBRARY="$IMG/lib/libSDL2_image.so" \
    -DCMAKE_EXE_LINKER_FLAGS="-Wl,-rpath,/opt/sdl2/lib -Wl,-rpath-link,$SDLROOT/lib" \
    "$SRCDIR/nxengine-evo-$VERSION" > "$OUT/configure.log" 2>&1 || { tail -30 "$OUT/configure.log"; exit 1; }
make -j"$(nproc)" > "$OUT/make.log" 2>&1 || { grep -E 'error|Error' "$OUT/make.log" | head -20; tail -15 "$OUT/make.log"; exit 1; }
make DESTDIR="$OUT/root" install > "$OUT/install.log" 2>&1 || { tail -15 "$OUT/install.log"; exit 1; }
ROOT="$OUT/root/opt/nxengine-evo"
for b in "$ROOT"/bin/*; do arm-linux-gnueabi-strip --strip-unneeded "$b"; done
cp "$SRCDIR/nxengine-evo-$VERSION/LICENSE" "$OUT/LICENSE"
echo "== Check"
find "$OUT/root" -maxdepth 4 -type d | sed "s|$OUT/root||" | head -12
file "$ROOT/bin/nxengine-evo" | cut -c1-140
arm-linux-gnueabi-readelf -d "$ROOT/bin/nxengine-evo" | grep -E "NEEDED|RPATH|RUNPATH"
echo -n "Highest glibc symbol: "
arm-linux-gnueabi-objdump -T "$ROOT"/bin/* | grep -oE 'GLIBC_[0-9.]+' | sort -uV | tail -1
ls -l "$ROOT"/bin/*; du -sh "$ROOT/share"
