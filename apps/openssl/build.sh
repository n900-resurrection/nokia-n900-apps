#!/bin/bash
# Cross-build OpenSSL 3.x (static libssl.a + libcrypto.a) for Maemo 5 (armel, glibc 2.5).
# Run INSIDE the Workshop:
#   workshop exec n900 -- bash -c 'VERSION=3.5.9 /project/apps/openssl/build.sh'
#   (or on the host: make -C apps/openssl build)
#
# Why: the device has OpenSSL 0.9.8n (TLS 1.0 only). Programs that need modern TLS (mutt, Python's
# ssl module, ...) link this copy statically, so they do not depend on the system library.
# Output: /project/build/deps/openssl-$VERSION/{include,lib}  (use via MAEMO_DEPS, see scripts/maemo-gcc)
set -euo pipefail

VERSION="${VERSION:-3.5.9}"
PROJ=/project
SR="$PROJ/sysroot"
DL="$PROJ/build/downloads"
SRCDIR="$PROJ/build/src"
PREFIX="$PROJ/build/deps/openssl-$VERSION"
OBJ="$PROJ/build/obj/openssl-$VERSION"

[ -d "$SR/usr/include" ] || { echo "Missing sysroot, run: make sysroot"; exit 1; }
mkdir -p "$DL" "$SRCDIR"
f="openssl-$VERSION.tar.gz"
[ -s "$DL/$f" ] || curl -fL --retry 3 -o "$DL/$f" "https://github.com/openssl/openssl/releases/download/openssl-$VERSION/$f"
echo "sha256 $(sha256sum "$DL/$f" | cut -d' ' -f1)  $f"

rm -rf "$SRCDIR/openssl-$VERSION" "$PREFIX" "$OBJ"
tar -C "$SRCDIR" -xzf "$DL/$f"
mkdir -p "$OBJ"
cd "$OBJ"

# Options:
#  - linux-armv4: 32-bit ARM target (uses NEON assembler when the CPU has it, runtime-detected).
#  - no-shared: static libraries only. no-tests/no-docs: faster build.
#  - no-afalgeng: needs linux/if_alg.h, newer than the 2.6.28 kernel headers of the SDK.
#  - no-async: avoids ucontext code that glibc 2.5 on ARM may not have.
#  - no-secure-memory: no mlock/mmap tricks, simpler on a small system.
#  - no-ktls: kernel TLS needs newer headers.
#  - --with-rand-seed=devrandom: the 2.6.28 kernel has no getrandom(); read /dev/urandom directly.
#    (OpenSSL then waits for nothing, unlike the blocking /dev/random.)
CC="$PROJ/scripts/maemo-gcc" AR=arm-linux-gnueabi-ar RANLIB=arm-linux-gnueabi-ranlib \
"$SRCDIR/openssl-$VERSION/Configure" linux-armv4 \
    --prefix="$PREFIX" --openssldir=/opt/openssl/etc/ssl \
    no-shared no-tests no-docs no-afalgeng no-async no-ktls no-secure-memory no-dso \
    --with-rand-seed=devrandom -Os \
    > "$PROJ/build/openssl-configure.log" 2>&1 || { tail -30 "$PROJ/build/openssl-configure.log"; exit 1; }
make -j"$(nproc)" build_libs > "$PROJ/build/openssl-build.log" 2>&1 \
    || { grep -E 'error|Error' "$PROJ/build/openssl-build.log" | head -20; tail -15 "$PROJ/build/openssl-build.log"; exit 1; }
# Manual install of the libraries and headers (no programs, no docs).
mkdir -p "$PREFIX/lib" "$PREFIX/include"
cp libssl.a libcrypto.a "$PREFIX/lib/"
cp -r "$SRCDIR/openssl-$VERSION/include/openssl" "$PREFIX/include/"
cp include/openssl/*.h "$PREFIX/include/openssl/"
echo "OpenSSL $VERSION in $PREFIX: $(ls -l "$PREFIX/lib" | awk 'NR>1{print $9" "$5}' | tr '\n' ' ')"
