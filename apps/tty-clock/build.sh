#!/bin/bash
# Cross-build tty-clock for Maemo 5 (armel, glibc 2.5). Run INSIDE the Workshop:
#   workshop exec n900 -- bash -c 'VERSION=2.3 /project/apps/tty-clock/build.sh'   (or: make -C apps/tty-clock build)
# Output: /project/build/out/tty-clock-$VERSION/tty-clock (stripped binary)
#
# tty-clock uses plain ncurses (no wide characters), so it is linked DYNAMICALLY against the
# libncurses5 that the device already has (the sysroot has the same version, 5.7).
set -euo pipefail

VERSION="${VERSION:-2.3}"
PROJ=/project
SRC="$PROJ/build/upstream/tty-clock"
OUT="$PROJ/build/out/tty-clock-$VERSION"

[ -d "$PROJ/sysroot/usr/include" ] || { echo "Missing sysroot, run: make sysroot"; exit 1; }

# 1. Sources (upstream tag v$VERSION)
if [ ! -d "$SRC/.git" ]; then
    mkdir -p "$(dirname "$SRC")"
    git clone -q https://github.com/xorg62/tty-clock.git "$SRC"
fi
git -C "$SRC" fetch -q --tags
git -C "$SRC" checkout -q -f "v$VERSION"

# 2. Build. One source file; the upstream Makefile only adds ncurses flags, which we pass directly.
rm -rf "$OUT"; mkdir -p "$OUT"
"$PROJ/scripts/maemo-gcc" -Os -Wall -o "$OUT/tty-clock.unstripped" "$SRC/ttyclock.c" -lncurses
arm-linux-gnueabi-strip -o "$OUT/tty-clock" "$OUT/tty-clock.unstripped"
rm "$OUT/tty-clock.unstripped"

echo "== Check"
file "$OUT/tty-clock" | cut -c1-140
arm-linux-gnueabi-readelf -d "$OUT/tty-clock" | grep NEEDED
echo -n "Highest glibc symbol: "
arm-linux-gnueabi-objdump -T "$OUT/tty-clock" | grep -oE 'GLIBC_[0-9.]+' | sort -uV | tail -1
ls -l "$OUT/tty-clock"
