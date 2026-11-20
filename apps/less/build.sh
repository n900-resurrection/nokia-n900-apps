#!/bin/bash
# Cross-build GNU less for Maemo 5 (armel, glibc 2.5). Run INSIDE the Workshop: make -C apps/less build
# ncursesw 5.7 of the sysroot is linked statically (the phone has only plain libncurses5; UTF-8 needs the wide one), as for nano.
# Output: /project/build/out/less-$VERSION/root/opt/less/{bin,share}
set -euo pipefail

VERSION="${VERSION:-710}"
PROJ=/project
SR="$PROJ/sysroot"
DL="$PROJ/build/downloads"
SRCDIR="$PROJ/build/src"
OUT="$PROJ/build/out/less-$VERSION"
OBJ="$PROJ/build/obj/less-$VERSION"

[ -d "$SR/usr/include" ] || { echo "Missing sysroot, run: make sysroot"; exit 1; }
mkdir -p "$DL" "$SRCDIR"
f="less-$VERSION.tar.gz"
[ -s "$DL/$f" ] || curl -fL --retry 3 -o "$DL/$f" "https://www.greenwoodsoftware.com/less/$f"
echo "sha256 $(sha256sum "$DL/$f" | cut -d' ' -f1)  $f"
rm -rf "$SRCDIR/less-$VERSION" "$OBJ" "$OUT"
tar -C "$SRCDIR" -xzf "$DL/$f"
mkdir -p "$OBJ" "$OUT/root"
cd "$OBJ"
"$SRCDIR/less-$VERSION/configure" \
    --host=arm-linux-gnueabi --build="$(gcc -dumpmachine)" \
    --prefix=/opt/less \
    CC="$PROJ/scripts/maemo-gcc" \
    CFLAGS="-Os -include $PROJ/scripts/maemo-compat.h" \
    CPPFLAGS="-I$SR/usr/include/ncursesw -I$SR/usr/include" \
    LIBS="-L$SR/usr/lib -Wl,-Bstatic -lncursesw -Wl,-Bdynamic" \
    > "$OUT/configure.log" 2>&1 || { tail -30 "$OUT/configure.log"; exit 1; }
make -j"$(nproc)" > "$OUT/make.log" 2>&1 || { grep -E 'error|Error' "$OUT/make.log" | head -20; exit 1; }
make install DESTDIR="$OUT/root" INSTALL_PROGRAM="/usr/bin/install -c" >> "$OUT/make.log" 2>&1 || { tail -20 "$OUT/make.log"; exit 1; }
arm-linux-gnueabi-strip "$OUT/root/opt/less/bin/less"

BIN="$OUT/root/opt/less/bin/less"
echo "== Check"
file "$BIN" | cut -c1-140
arm-linux-gnueabi-readelf -d "$BIN" | grep NEEDED
echo -n "Highest glibc symbol: "
arm-linux-gnueabi-objdump -T "$BIN" | grep -oE 'GLIBC_[0-9.]+' | sort -uV | tail -1
ls -l "$BIN"
