#!/bin/bash
# Cross-build tig for Maemo 5. Run INSIDE the Workshop (make -C apps/tig build).
# Output: /project/build/out/tig-$VERSION/root/opt/tig/{bin,etc}
# The device has only the plain libncurses5, but tig needs ncursesw (UTF-8), so ncursesw 5.7 of the sysroot is linked statically (as in nano).
# tig runs `git` from the PATH (our git package).
set -euo pipefail

VERSION="${VERSION:-2.6.1}"
PROJ=/project
SR="$PROJ/sysroot"
DL="$PROJ/build/downloads"
SRCDIR="$PROJ/build/src"
OUT="$PROJ/build/out/tig-$VERSION"

[ -d "$SR/usr/include" ] || { echo "Missing sysroot, run: make sysroot"; exit 1; }
mkdir -p "$DL" "$SRCDIR"
f="tig-$VERSION.tar.gz"
[ -s "$DL/$f" ] || curl -fL --retry 3 -o "$DL/$f" "https://github.com/jonas/tig/releases/download/tig-$VERSION/$f"
echo "sha256 $(sha256sum "$DL/$f" | cut -d' ' -f1)  $f"
rm -rf "$SRCDIR/tig-$VERSION" "$OUT"
tar -C "$SRCDIR" -xzf "$DL/$f"
mkdir -p "$OUT/root"
cd "$SRCDIR/tig-$VERSION"
./configure --host=arm-linux-gnueabi --build="$(gcc -dumpmachine)" --prefix=/opt/tig --sysconfdir=/opt/tig/etc \
    --without-readline --with-ncursesw \
    CC="$PROJ/scripts/maemo-gcc" CFLAGS="-Os -D_GNU_SOURCE -include $PROJ/scripts/maemo-compat.h" \
    CPPFLAGS="-I$SR/usr/include/ncursesw -I$SR/usr/include" LDFLAGS="-L$SR/usr/lib" \
    CURSES_LIBS="-Wl,-Bstatic -lncursesw -Wl,-Bdynamic" \
    > "$OUT/configure.log" 2>&1 || { tail -30 "$OUT/configure.log"; exit 1; }
make -j"$(nproc)" > "$OUT/make.log" 2>&1 || { grep -E 'error|Error' "$OUT/make.log" | head -20; tail -15 "$OUT/make.log"; exit 1; }
make install-release-doc-man >/dev/null 2>&1 || true
mkdir -p "$OUT/root/opt/tig/bin" "$OUT/root/opt/tig/etc"
arm-linux-gnueabi-strip -o "$OUT/root/opt/tig/bin/tig" src/tig
cp contrib/tigrc "$OUT/root/opt/tig/etc/tigrc" 2>/dev/null || true
cp COPYING "$OUT/COPYING"
BIN="$OUT/root/opt/tig/bin/tig"
echo "== Check"
file "$BIN" | cut -c1-140
arm-linux-gnueabi-readelf -d "$BIN" | grep NEEDED
echo -n "Highest glibc symbol: "
arm-linux-gnueabi-objdump -T "$BIN" | grep -oE 'GLIBC_[0-9.]+' | sort -uV | tail -1
ls -l "$BIN"
