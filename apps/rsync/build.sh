#!/bin/bash
# Cross-build rsync for Maemo 5 (armel, glibc 2.5). Run INSIDE the Workshop (make -C apps/rsync build).
# Output: /project/build/out/rsync-$VERSION/root/opt/rsync/bin/rsync
# Without the optional libraries (xxhash, zstd, lz4, openssl, acl, attr): the bundled popt and zlib are used, so the binary needs only glibc.
# Transport over SSH (the ssh of the phone is used); the daemon mode is built too but nothing starts it.
set -euo pipefail

VERSION="${VERSION:-3.5.2}"
PROJ=/project
SR="$PROJ/sysroot"
DL="$PROJ/build/downloads"
SRCDIR="$PROJ/build/src"
OUT="$PROJ/build/out/rsync-$VERSION"

[ -d "$SR/usr/include" ] || { echo "Missing sysroot, run: make sysroot"; exit 1; }
mkdir -p "$DL" "$SRCDIR"
f="rsync-$VERSION.tar.gz"
[ -s "$DL/$f" ] || curl -fL --retry 3 -o "$DL/$f" "https://github.com/RsyncProject/rsync/releases/download/v$VERSION/$f"
echo "sha256 $(sha256sum "$DL/$f" | cut -d' ' -f1)  $f"
rm -rf "$SRCDIR/rsync-$VERSION" "$OUT"
tar -C "$SRCDIR" -xzf "$DL/$f"
mkdir -p "$OUT/root"
cd "$SRCDIR/rsync-$VERSION"
./configure --host=arm-linux-gnueabi --build="$(gcc -dumpmachine)" --prefix=/opt/rsync \
    --disable-xxhash --disable-zstd --disable-lz4 --disable-openssl --disable-acl-support --disable-xattr-support \
    --disable-idn --disable-md2man --disable-locale --with-included-popt --with-included-zlib --disable-debug \
    CC="$PROJ/scripts/maemo-gcc" CFLAGS="-Os -D_GNU_SOURCE -include $PROJ/scripts/maemo-compat.h" \
    > "$OUT/configure.log" 2>&1 || { tail -30 "$OUT/configure.log"; exit 1; }
make -j"$(nproc)" > "$OUT/make.log" 2>&1 || { grep -E 'error|Error' "$OUT/make.log" | head -20; tail -15 "$OUT/make.log"; exit 1; }
mkdir -p "$OUT/root/opt/rsync/bin"
arm-linux-gnueabi-strip -o "$OUT/root/opt/rsync/bin/rsync" rsync
BIN="$OUT/root/opt/rsync/bin/rsync"
echo "== Check"
file "$BIN" | cut -c1-140
arm-linux-gnueabi-readelf -d "$BIN" | grep NEEDED
echo -n "Highest glibc symbol: "
arm-linux-gnueabi-objdump -T "$BIN" | grep -oE 'GLIBC_[0-9.]+' | sort -uV | tail -1
ls -l "$BIN"
