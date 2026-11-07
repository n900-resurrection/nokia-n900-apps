#!/bin/bash
# Cross-build GNU nano for Maemo 5 (armel, glibc 2.5). Run INSIDE the Workshop:
#   workshop exec n900 -- bash -c 'VERSION=9.3 /project/apps/nano/build.sh'   (or: make -C apps/nano build)
# Output: /project/build/out/nano-$VERSION/root/opt/nano/{bin,share}   (installed tree)
#
# The device has only the plain libncurses5, but nano needs ncursesw for UTF-8 (Czech text), so ncursesw 5.7 of the sysroot
# is linked STATICALLY (like htop 3). No gettext/NLS (the messages stay English).
set -euo pipefail

VERSION="${VERSION:-9.3}"
PROJ=/project
SR="$PROJ/sysroot"
DL="$PROJ/build/downloads"
SRCDIR="$PROJ/build/src"
OUT="$PROJ/build/out/nano-$VERSION"
OBJ="$PROJ/build/obj/nano-$VERSION"

[ -d "$SR/usr/include" ] || { echo "Missing sysroot, run: make sysroot"; exit 1; }
mkdir -p "$DL" "$SRCDIR"
f="nano-$VERSION.tar.xz"
[ -s "$DL/$f" ] || curl -fL --retry 3 -o "$DL/$f" "https://www.nano-editor.org/dist/v${VERSION%%.*}/$f"
echo "sha256 $(sha256sum "$DL/$f" | cut -d' ' -f1)  $f"
rm -rf "$SRCDIR/nano-$VERSION" "$OBJ" "$OUT"
tar -C "$SRCDIR" -xJf "$DL/$f"
mkdir -p "$OBJ" "$OUT/root"
cd "$OBJ"
# scripts/maemo-compat.h supplies what the glibc 2.5 headers lack (O_CLOEXEC, ...).
"$SRCDIR/nano-$VERSION/configure" \
    --host=arm-linux-gnueabi --build="$(gcc -dumpmachine)" \
    --prefix=/opt/nano --sysconfdir=/opt/nano/etc \
    --enable-utf8 --disable-nls --disable-libmagic \
    CC="$PROJ/scripts/maemo-gcc" \
    CFLAGS="-Os -include $PROJ/scripts/maemo-compat.h" \
    NCURSESW_CFLAGS="-I$SR/usr/include/ncursesw -I$SR/usr/include" \
    NCURSESW_LIBS="-L$SR/usr/lib -Wl,-Bstatic -lncursesw -Wl,-Bdynamic" \
    > "$OUT/configure.log" 2>&1 || { tail -30 "$OUT/configure.log"; exit 1; }
make -j"$(nproc)" > "$OUT/make.log" 2>&1 || { grep -E 'error|Error' "$OUT/make.log" | head -20; exit 1; }
make install-strip DESTDIR="$OUT/root" >> "$OUT/make.log" 2>&1 || { tail -20 "$OUT/make.log"; exit 1; }

BIN="$OUT/root/opt/nano/bin/nano"
echo "== Check"
file "$BIN" | cut -c1-140
arm-linux-gnueabi-readelf -d "$BIN" | grep NEEDED
echo -n "Highest glibc symbol: "
arm-linux-gnueabi-objdump -T "$BIN" | grep -oE 'GLIBC_[0-9.]+' | sort -uV | tail -1
ls -l "$BIN"
