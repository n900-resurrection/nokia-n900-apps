#!/bin/bash
# Cross-build ncdu 1.x (the C version; 2.x is written in Zig) for Maemo 5. Run INSIDE the Workshop (make -C apps/ncdu build).
# Output: /project/build/out/ncdu-$VERSION/root/opt/ncdu/{bin,share}
# ncdu uses the plain libncurses5 of the device (the sysroot has the same version 5.7).
set -euo pipefail

VERSION="${VERSION:-1.22}"
PROJ=/project
SR="$PROJ/sysroot"
DL="$PROJ/build/downloads"
SRCDIR="$PROJ/build/src"
OUT="$PROJ/build/out/ncdu-$VERSION"

[ -d "$SR/usr/include" ] || { echo "Missing sysroot, run: make sysroot"; exit 1; }
mkdir -p "$DL" "$SRCDIR"
f="ncdu-$VERSION.tar.gz"
[ -s "$DL/$f" ] || curl -fL --retry 3 -o "$DL/$f" "https://dev.yorhel.nl/download/$f"
echo "sha256 $(sha256sum "$DL/$f" | cut -d' ' -f1)  $f"
rm -rf "$SRCDIR/ncdu-$VERSION" "$OUT"
tar -C "$SRCDIR" -xzf "$DL/$f"
mkdir -p "$OUT/root"
cd "$SRCDIR/ncdu-$VERSION"
./configure --host=arm-linux-gnueabi --build="$(gcc -dumpmachine)" --prefix=/opt/ncdu \
    CC="$PROJ/scripts/maemo-gcc" CFLAGS="-Os -D_GNU_SOURCE -include $PROJ/scripts/maemo-compat.h" \
    NCURSES_CFLAGS="-I$SR/usr/include" NCURSES_LIBS="-lncurses" \
    > "$OUT/configure.log" 2>&1 || { tail -30 "$OUT/configure.log"; exit 1; }
make -j"$(nproc)" > "$OUT/make.log" 2>&1 || { grep -E 'error|Error' "$OUT/make.log" | head -20; tail -15 "$OUT/make.log"; exit 1; }
make install-strip DESTDIR="$OUT/root" >> "$OUT/make.log" 2>&1 || { tail -20 "$OUT/make.log"; exit 1; }
BIN="$OUT/root/opt/ncdu/bin/ncdu"
echo "== Check"
file "$BIN" | cut -c1-140
arm-linux-gnueabi-readelf -d "$BIN" | grep NEEDED
echo -n "Highest glibc symbol: "
arm-linux-gnueabi-objdump -T "$BIN" | grep -oE 'GLIBC_[0-9.]+' | sort -uV | tail -1
ls -l "$BIN"
