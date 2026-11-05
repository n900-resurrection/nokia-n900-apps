#!/bin/bash
# Cross-build GNU Wget 1.25 with TLS 1.2/1.3 (static OpenSSL 3) for Maemo 5. Run INSIDE the Workshop:
#   workshop exec n900 -- bash -c 'VERSION=1.25.0 /project/apps/wget/build.sh'   (or: make -C apps/wget build)
# Needs the static OpenSSL (make -C apps/openssl build) and the private zlib that apps/curl builds.
# Output: /project/build/out/wget-$VERSION/wget   (stripped binary)
#
# The device has wget 1.10.2 with OpenSSL 0.9.8 (TLS 1.0 only), so it cannot fetch from modern HTTPS sites.
set -euo pipefail

VERSION="${VERSION:-1.25.0}"
OPENSSL_VERSION="${OPENSSL_VERSION:-3.5.9}"
ZLIB_VERSION="${ZLIB_VERSION:-1.3.2}"
PROJ=/project
SR="$PROJ/sysroot"
DL="$PROJ/build/downloads"
SRCDIR="$PROJ/build/src"
OUT="$PROJ/build/out/wget-$VERSION"
OBJ="$PROJ/build/obj/wget-$VERSION"
SSL="$PROJ/build/deps/openssl-$OPENSSL_VERSION"
ZDIR="$PROJ/build/deps/zlib-$ZLIB_VERSION"

[ -d "$SR/usr/include" ] || { echo "Missing sysroot, run: make sysroot"; exit 1; }
[ -f "$SSL/lib/libssl.a" ] || { echo "Missing OpenSSL, run: make -C apps/openssl build"; exit 1; }
[ -f "$ZDIR/lib/libz.a" ] || { echo "Missing zlib, run: make -C apps/curl build"; exit 1; }
mkdir -p "$DL" "$SRCDIR"
f="wget-$VERSION.tar.gz"
[ -s "$DL/$f" ] || curl -fL --retry 3 -o "$DL/$f" "https://ftp.gnu.org/gnu/wget/$f"
echo "sha256 $(sha256sum "$DL/$f" | cut -d' ' -f1)  $f"
rm -rf "$SRCDIR/wget-$VERSION" "$OBJ" "$OUT"
tar -C "$SRCDIR" -xzf "$DL/$f"
mkdir -p "$OBJ" "$OUT/root"
cd "$OBJ"

# Our OpenSSL and zlib must win over the old ones in the sysroot (see scripts/maemo-gcc).
export MAEMO_DEPS="$SSL:$ZDIR"
# - libcrypto.a uses dlopen-free code (no-dso) but needs pthread; -ldl is harmless.
# - Optional libraries (PCRE, libpsl, libuuid, libidn2, metalink, nghttp2) are switched off: not on the device.
# - --disable-nls: no gettext. --without-... keeps the dependency list to libc.
# - The CA file is set in the shipped wgetrc, see package.sh.
"$SRCDIR/wget-$VERSION/configure" \
    --host=arm-linux-gnueabi --build="$(gcc -dumpmachine)" \
    --prefix=/opt/wget --sysconfdir=/opt/wget/etc \
    --with-ssl=openssl --with-libssl-prefix="$SSL" \
    --without-libpsl --without-libuuid --disable-pcre --disable-pcre2 --without-libidn --without-metalink \
    --disable-nls --disable-iri --disable-ipv6 --disable-debug --disable-rpath \
    CC="$PROJ/scripts/maemo-gcc" \
    CFLAGS="-Os -include $PROJ/scripts/maemo-compat.h -DO_BINARY=0 -DO_TEXT=0" \
    LIBS="-ldl -lpthread" \
    OPENSSL_CFLAGS="-I$SSL/include" OPENSSL_LIBS="$SSL/lib/libssl.a $SSL/lib/libcrypto.a -ldl -lpthread" \
    ZLIB_CFLAGS="-I$ZDIR/include" ZLIB_LIBS="$ZDIR/lib/libz.a" \
    > "$OUT/configure.log" 2>&1 || { tail -30 "$OUT/configure.log"; exit 1; }
make -j"$(nproc)" -C lib > "$OUT/make.log" 2>&1 && make -j"$(nproc)" -C src >> "$OUT/make.log" 2>&1 || { grep -E 'error|Error' "$OUT/make.log" | head -20; exit 1; }
arm-linux-gnueabi-strip -o "$OUT/wget" src/wget

echo "== Check"
file "$OUT/wget" | cut -c1-140
ls -l "$OUT/wget"
