#!/bin/bash
# Cross-build whiptail (part of newt) for Maemo 5. Run INSIDE the Workshop (make -C apps/whiptail build).
# Output: /project/build/out/whiptail-$VERSION/root/opt/whiptail/bin/whiptail
# newt needs slang and popt; the device has an old libslang 2.0.6 without headers, so slang 2.3.3 is built and linked statically (with popt of the sysroot).
set -euo pipefail

VERSION="${VERSION:-0.52.25}"
SLANG=2.3.3
PROJ=/project
SR="$PROJ/sysroot"
DL="$PROJ/build/downloads"
SRCDIR="$PROJ/build/src"
OUT="$PROJ/build/out/whiptail-$VERSION"
DEPS="$OUT/deps"

[ -d "$SR/usr/include" ] || { echo "Missing sysroot, run: make sysroot"; exit 1; }
mkdir -p "$DL" "$SRCDIR"
# Both tarballs are the upstream ones, taken from the Debian archive.
fetch() { [ -s "$DL/$1" ] || curl -fL --retry 3 -o "$DL/$1" "$2/$1"; echo "sha256 $(sha256sum "$DL/$1" | cut -d' ' -f1)  $1"; }
fetch "slang2_$SLANG.orig.tar.xz" https://deb.debian.org/debian/pool/main/s/slang2
fetch "newt_$VERSION.orig.tar.xz" https://deb.debian.org/debian/pool/main/n/newt
rm -rf "$SRCDIR/slang2-$SLANG" "$SRCDIR/newt-$VERSION" "$OUT"
mkdir -p "$OUT/root" "$DEPS"
tar -C "$SRCDIR" -xJf "$DL/slang2_$SLANG.orig.tar.xz"
tar -C "$SRCDIR" -xJf "$DL/newt_$VERSION.orig.tar.xz"
export CC="$PROJ/scripts/maemo-gcc"

echo "== slang $SLANG (static)"
cd "$SRCDIR/slang2-$SLANG"
./configure --host=arm-linux-gnueabi --build="$(gcc -dumpmachine)" --prefix="$DEPS" \
    --without-png --without-pcre --without-onig --without-z --without-iconv \
    CFLAGS="-Os -D_GNU_SOURCE" > "$OUT/slang-configure.log" 2>&1 || { tail -30 "$OUT/slang-configure.log"; exit 1; }
make -j"$(nproc)" static > "$OUT/slang-make.log" 2>&1 || { grep -E 'error|Error' "$OUT/slang-make.log" | head; tail -15 "$OUT/slang-make.log"; exit 1; }
mkdir -p "$DEPS/lib" "$DEPS/include"
cp src/*/libslang.a "$DEPS/lib/"
cp src/slang.h src/slcurses.h "$DEPS/include/"

echo "== newt $VERSION"
cd "$SRCDIR/newt-$VERSION"
./configure --host=arm-linux-gnueabi --build="$(gcc -dumpmachine)" --prefix=/opt/whiptail \
    --without-python --without-tcl --disable-nls \
    CFLAGS="-Os -D_GNU_SOURCE" CPPFLAGS="-I$DEPS/include -I$SR/usr/include" LDFLAGS="-L$DEPS/lib -L$SR/usr/lib" \
    > "$OUT/configure.log" 2>&1 || { tail -30 "$OUT/configure.log"; exit 1; }
# The Makefile links whiptail with the shared libnewt and a dynamic popt; link by hand with everything static except libc.
make -j"$(nproc)" libnewt.a whiptail.o dialogboxes.o > "$OUT/make.log" 2>&1 || { grep -E 'error|Error' "$OUT/make.log" | head -20; tail -15 "$OUT/make.log"; exit 1; }
"$CC" -o whiptail whiptail.o dialogboxes.o libnewt.a "$DEPS/lib/libslang.a" "$SR/usr/lib/libpopt.a" -lm >> "$OUT/make.log" 2>&1 || { tail -15 "$OUT/make.log"; exit 1; }
mkdir -p "$OUT/root/opt/whiptail/bin" "$OUT/root/opt/whiptail/share/man/man1"
arm-linux-gnueabi-strip -o "$OUT/root/opt/whiptail/bin/whiptail" whiptail
cp COPYING "$OUT/COPYING"
BIN="$OUT/root/opt/whiptail/bin/whiptail"
echo "== Check"
file "$BIN" | cut -c1-140
arm-linux-gnueabi-readelf -d "$BIN" | grep NEEDED
echo -n "Highest glibc symbol: "
arm-linux-gnueabi-objdump -T "$BIN" | grep -oE 'GLIBC_[0-9.]+' | sort -uV | tail -1
ls -l "$BIN"
