#!/bin/bash
# Cross-build file(1) and its magic database for Maemo 5. Run INSIDE the Workshop (make -C apps/file build).
# Output: /project/build/out/file-$VERSION/root/opt/file/{bin,share/misc/magic.mgc}
# The magic database is compiled by a NATIVE file of the same version (file refuses a database of another version): it is built first.
# libmagic is linked statically into the program; no compression libraries (zlib/bzip2/xz/zstd: files are not looked into).
set -euo pipefail

VERSION="${VERSION:-5.48}"
PROJ=/project
SR="$PROJ/sysroot"
DL="$PROJ/build/downloads"
SRCDIR="$PROJ/build/src"
OUT="$PROJ/build/out/file-$VERSION"
NAT="$PROJ/build/obj/file-native-$VERSION"

[ -d "$SR/usr/include" ] || { echo "Missing sysroot, run: make sysroot"; exit 1; }
mkdir -p "$DL" "$SRCDIR"
f="file-$VERSION.tar.gz"
[ -s "$DL/$f" ] || curl -fL --retry 3 -o "$DL/$f" "https://astron.com/pub/file/$f"
echo "sha256 $(sha256sum "$DL/$f" | cut -d' ' -f1)  $f"
rm -rf "$SRCDIR/file-$VERSION" "$OUT" "$NAT"
tar -C "$SRCDIR" -xzf "$DL/$f"
mkdir -p "$OUT/root" "$NAT"

# 1. native build (only for its `file` program, which compiles the magic database)
( cd "$NAT" && "$SRCDIR/file-$VERSION/configure" --disable-shared --disable-libseccomp --disable-zlib --disable-bzlib --disable-xzlib \
      --disable-zstdlib --disable-lzlib > "$OUT/native-configure.log" 2>&1 && make -j"$(nproc)" > "$OUT/native-make.log" 2>&1 ) \
    || { tail -20 "$OUT/native-configure.log" "$OUT/native-make.log" 2>/dev/null; exit 1; }

# 2. cross build
cd "$SRCDIR/file-$VERSION"
rm -rf "$OUT/obj"; mkdir -p "$OUT/obj"; cd "$OUT/obj"
"$SRCDIR/file-$VERSION/configure" --host=arm-linux-gnueabi --build="$(gcc -dumpmachine)" --prefix=/opt/file \
    --disable-shared --enable-static --disable-libseccomp --disable-zlib --disable-bzlib --disable-xzlib --disable-zstdlib --disable-lzlib \
    CC="$PROJ/scripts/maemo-gcc" CFLAGS="-Os -D_GNU_SOURCE -include $PROJ/scripts/maemo-compat.h" \
    > "$OUT/configure.log" 2>&1 || { tail -30 "$OUT/configure.log"; exit 1; }
make -j"$(nproc)" FILE_COMPILE="$NAT/src/file" > "$OUT/make.log" 2>&1 || { grep -E 'error|Error' "$OUT/make.log" | head -20; tail -15 "$OUT/make.log"; exit 1; }
make install-strip DESTDIR="$OUT/root" FILE_COMPILE="$NAT/src/file" >> "$OUT/make.log" 2>&1 || { tail -20 "$OUT/make.log"; exit 1; }

BIN="$OUT/root/opt/file/bin/file"
echo "== Check"
file "$BIN" | cut -c1-140
arm-linux-gnueabi-readelf -d "$BIN" | grep NEEDED
echo -n "Highest glibc symbol: "
arm-linux-gnueabi-objdump -T "$BIN" | grep -oE 'GLIBC_[0-9.]+' | sort -uV | tail -1
ls -l "$BIN" "$OUT/root/opt/file/share/misc/magic.mgc"
