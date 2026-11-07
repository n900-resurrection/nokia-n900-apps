#!/bin/bash
# Cross-build dialog for Maemo 5. Run INSIDE the Workshop (make -C apps/dialog build).
# Output: /project/build/out/dialog-$VERSION/root/opt/dialog/bin/dialog
# The device has only the plain libncurses5, so ncursesw 5.7 of the sysroot is linked statically (UTF-8 and line drawing), as in tig.
set -euo pipefail

VERSION="${VERSION:-1.3-20260721}"
PROJ=/project
SR="$PROJ/sysroot"
DL="$PROJ/build/downloads"
SRCDIR="$PROJ/build/src"
OUT="$PROJ/build/out/dialog-$VERSION"

[ -d "$SR/usr/include" ] || { echo "Missing sysroot, run: make sysroot"; exit 1; }
mkdir -p "$DL" "$SRCDIR"
# The upstream site (invisible-island.net) refuses the default curl User-Agent, so the same upstream tarball is taken from the Debian archive.
f="dialog_$VERSION.orig.tar.gz"
[ -s "$DL/$f" ] || curl -fL --retry 3 -o "$DL/$f" "https://deb.debian.org/debian/pool/main/d/dialog/$f"
echo "sha256 $(sha256sum "$DL/$f" | cut -d' ' -f1)  $f"
rm -rf "$SRCDIR/dialog-$VERSION" "$OUT"
tar -C "$SRCDIR" -xzf "$DL/$f"
mkdir -p "$OUT/root"
cd "$SRCDIR/dialog-$VERSION"
./configure --host=arm-linux-gnueabi --build="$(gcc -dumpmachine)" --prefix=/opt/dialog \
    --with-ncursesw --disable-nls --without-libtool \
    CC="$PROJ/scripts/maemo-gcc" CFLAGS="-Os -D_GNU_SOURCE" \
    CPPFLAGS="-I$SR/usr/include/ncursesw -I$SR/usr/include" LDFLAGS="-L$SR/usr/lib" \
    LIBS="-Wl,-Bstatic -lncursesw -Wl,-Bdynamic" \
    > "$OUT/configure.log" 2>&1 || { tail -30 "$OUT/configure.log"; exit 1; }
make -j"$(nproc)" > "$OUT/make.log" 2>&1 || { grep -E 'error|Error' "$OUT/make.log" | head -20; tail -15 "$OUT/make.log"; exit 1; }
mkdir -p "$OUT/root/opt/dialog/bin" "$OUT/root/opt/dialog/share/man/man1"
arm-linux-gnueabi-strip -o "$OUT/root/opt/dialog/bin/dialog" dialog
gzip -9n -c dialog.1 > "$OUT/root/opt/dialog/share/man/man1/dialog.1.gz"
cp COPYING "$OUT/COPYING"
BIN="$OUT/root/opt/dialog/bin/dialog"
echo "== Check"
file "$BIN" | cut -c1-140
arm-linux-gnueabi-readelf -d "$BIN" | grep NEEDED
echo -n "Highest glibc symbol: "
arm-linux-gnueabi-objdump -T "$BIN" | grep -oE 'GLIBC_[0-9.]+' | sort -uV | tail -1
ls -l "$BIN"
