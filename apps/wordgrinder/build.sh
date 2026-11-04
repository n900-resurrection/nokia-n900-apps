#!/bin/bash
# Cross-build WordGrinder for Maemo 5 (armel, glibc 2.5). Run INSIDE the Workshop:
#   workshop exec n900 -- bash -c 'VERSION=0.8 /project/apps/wordgrinder/build.sh'
#   (or on the host: make -C apps/wordgrinder build)
# Output: /project/build/out/wordgrinder-$VERSION/opt/wordgrinder/...  (installed tree)
#         /project/build/out/wordgrinder-$VERSION/wordgrinder          (stripped binary)
#
# Verified 2026-11-04 for VERSION=0.8 (bundled Lua 5.1, ncursesw linked statically).
set -euo pipefail

VERSION="${VERSION:-0.8}"
PROJ=/project
SR="$PROJ/sysroot"
SRC="$PROJ/build/upstream/wordgrinder"
OUT="$PROJ/build/out/wordgrinder-$VERSION"
OBJ="$PROJ/build/obj/wordgrinder-$VERSION"

[ -d "$SR/usr/include" ] || { echo "Missing sysroot, run: make sysroot"; exit 1; }

# 1. Upstream sources (kept outside version control)
if [ ! -d "$SRC/.git" ]; then
    mkdir -p "$(dirname "$SRC")"
    git clone -q https://github.com/davidgiven/wordgrinder.git "$SRC"
fi
git -C "$SRC" checkout -q -f "$VERSION"

# 2. Host Lua interpreter. The upstream Makefile would otherwise build it with the target $(CC),
#    and an ARM binary cannot be run on the build machine.
mkdir -p "$PROJ/build/host"
gcc -O -o "$PROJ/build/host/lua" \
    "$SRC"/src/c/emu/lua-5.1.5/*.c "$SRC"/src/c/emu/tmpnam.c -lm -DLUA_USE_EMU_TMPNAM

# 3. Target build.
#  - ncursesw: the wide-character header lives in usr/include/ncursesw. The library is linked
#    STATICALLY because the device does not have it (it only has libc, libm and libz).
#  - WANT_STRIPPED_BINARIES=no: the upstream Makefile calls the host strip; we strip below.
rm -rf "$OBJ" "$OUT"
make -C "$SRC" clean >/dev/null 2>&1 || true
make -C "$SRC" install-notests \
    LUA_INTERPRETER="$PROJ/build/host/lua" OBJDIR="$OBJ" \
    CC="$PROJ/scripts/maemo-gcc" NINJA=ninja VERSION="$VERSION" \
    CURSES_PACKAGE="--cflags={-I$SR/usr/include/ncursesw -I$SR/usr/include} --libs={-L$SR/usr/lib -Wl,-Bstatic -lncursesw -Wl,-Bdynamic}" \
    WANT_STRIPPED_BINARIES=no \
    PREFIX=/opt/wordgrinder DESTDIR="$OUT"

BIN="$OUT/opt/wordgrinder/bin/wordgrinder"
arm-linux-gnueabi-strip -o "$OUT/wordgrinder" "$BIN"

echo "== Check"
file "$OUT/wordgrinder" | cut -c1-140
arm-linux-gnueabi-readelf -d "$OUT/wordgrinder" | grep NEEDED
echo -n "Highest glibc symbol: "
arm-linux-gnueabi-objdump -T "$OUT/wordgrinder" | grep -oE 'GLIBC_[0-9.]+' | sort -uV | tail -1
ls -l "$OUT/wordgrinder"
