#!/bin/bash
# Cross-build strace for Maemo 5 (armel, glibc 2.5, kernel headers 2.6.28). Run INSIDE the Workshop (make -C apps/strace build).
# Output: /project/build/out/strace-$VERSION/root/opt/strace/{bin,share}
# Only the native ABI (--enable-mpers=no). --enable-bundled=yes: the kernel headers of the sysroot (2.6.28) miss many constants, strace brings its own copies.
set -euo pipefail

VERSION="${VERSION:-6.19}"
PROJ=/project
SR="$PROJ/sysroot"
DL="$PROJ/build/downloads"
SRCDIR="$PROJ/build/src"
OUT="$PROJ/build/out/strace-$VERSION"

[ -d "$SR/usr/include" ] || { echo "Missing sysroot, run: make sysroot"; exit 1; }
mkdir -p "$DL" "$SRCDIR"
f="strace-$VERSION.tar.xz"
[ -s "$DL/$f" ] || curl -fL --retry 3 -o "$DL/$f" "https://github.com/strace/strace/releases/download/v$VERSION/$f"
echo "sha256 $(sha256sum "$DL/$f" | cut -d' ' -f1)  $f"
rm -rf "$SRCDIR/strace-$VERSION" "$OUT"
tar -C "$SRCDIR" -xJf "$DL/$f"
mkdir -p "$OUT/root"
cd "$SRCDIR/strace-$VERSION"
# maemo-gcc puts the headers of the sysroot first, so the bundled kernel headers (-isystem in the strace Makefiles) would lose against the old
# 2.6.28 ones: they are copied into one directory that is searched BEFORE the sysroot (MAEMO_DEPS, see scripts/maemo-gcc).
H="$OUT/hdr"; mkdir -p "$H/include"
cp -a bundled/linux/include/uapi/. "$H/include/"
cp -a bundled/linux/arch/arm/include/uapi/. "$H/include/"
export MAEMO_DEPS="$H"
./configure --host=arm-linux-gnueabi --build="$(gcc -dumpmachine)" --prefix=/opt/strace \
    --enable-mpers=no --enable-bundled=yes --disable-gcc-Werror --without-libunwind --without-libdw --without-libiberty \
    CC="$PROJ/scripts/maemo-gcc" CFLAGS="-Os -D_GNU_SOURCE -include $PROJ/scripts/maemo-compat.h" \
    > "$OUT/configure.log" 2>&1 || { tail -30 "$OUT/configure.log"; exit 1; }
make -j"$(nproc)" > "$OUT/make.log" 2>&1 || { grep -E 'error|Error' "$OUT/make.log" | head -20; tail -15 "$OUT/make.log"; exit 1; }
make install-strip DESTDIR="$OUT/root" >> "$OUT/make.log" 2>&1 || { tail -20 "$OUT/make.log"; exit 1; }
BIN="$OUT/root/opt/strace/bin/strace"
echo "== Check"
file "$BIN" | cut -c1-140
arm-linux-gnueabi-readelf -d "$BIN" | grep NEEDED
echo -n "Highest glibc symbol: "
arm-linux-gnueabi-objdump -T "$BIN" | grep -oE 'GLIBC_[0-9.]+' | sort -uV | tail -1
ls -l "$BIN"
