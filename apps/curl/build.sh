#!/bin/bash
# Cross-build a modern curl (TLS 1.2/1.3 via mbedTLS) for Maemo 5 (armel, glibc 2.5).
# Run INSIDE the Workshop:
#   workshop exec n900 -- bash -c 'CURL_VERSION=8.23.0 MBEDTLS_VERSION=3.6.7 ZLIB_VERSION=1.3.2 /project/apps/curl/build.sh'
#   (or on the host: make -C apps/curl build)
#
# Why: the device ships OpenSSL 0.9.8n (TLS 1.0 only), libcurl 7.18 and wget 1.10, so it cannot
# talk HTTPS to modern servers (GitHub, Wikipedia, ...). mbedTLS and libcurl are linked statically
# into the binary, so nothing here depends on the old system OpenSSL.
#
# Output (OUT=/project/build/out/curl-$CURL_VERSION):
#   root/opt/curl/...   installed tree (curl binary, static libcurl.a, headers, curl-config)
#   curl                stripped binary
#   cacert.pem          Mozilla CA bundle (from curl.se) used as the default CA store
set -euo pipefail

CURL_VERSION="${CURL_VERSION:-8.23.0}"
MBEDTLS_VERSION="${MBEDTLS_VERSION:-3.6.7}"
ZLIB_VERSION="${ZLIB_VERSION:-1.3.2}"
PROJ=/project
SR="$PROJ/sysroot"
DL="$PROJ/build/downloads"
SRCDIR="$PROJ/build/src"
OUT="$PROJ/build/out/curl-$CURL_VERSION"
DEPS="$PROJ/build/deps/mbedtls-$MBEDTLS_VERSION"
ZDIR="$PROJ/build/deps/zlib-$ZLIB_VERSION"
CC="$PROJ/scripts/maemo-gcc"
AR=arm-linux-gnueabi-ar
RANLIB=arm-linux-gnueabi-ranlib

[ -d "$SR/usr/include" ] || { echo "Missing sysroot, run: make sysroot"; exit 1; }
mkdir -p "$DL" "$SRCDIR"

# Download a file once and print its SHA-256, so a later release check can pin it.
fetch() {  # fetch <url> <file>
    [ -s "$DL/$2" ] || curl -fL --retry 3 -o "$DL/$2" "$1"
    echo "sha256 $(sha256sum "$DL/$2" | cut -d' ' -f1)  $2"
}
command -v curl >/dev/null || sudo apt-get install -y curl ca-certificates

# 0. zlib (static). The SDK has zlib 1.2.3, but curl 8.x needs 1.2.5.2 or newer. Linking a private
#    static copy also means the binary does not depend on the zlib of the device.
fetch "https://github.com/madler/zlib/releases/download/v$ZLIB_VERSION/zlib-$ZLIB_VERSION.tar.xz" "zlib-$ZLIB_VERSION.tar.xz"
rm -rf "$SRCDIR/zlib-$ZLIB_VERSION" "$ZDIR"
tar -C "$SRCDIR" -xJf "$DL/zlib-$ZLIB_VERSION.tar.xz"
(cd "$SRCDIR/zlib-$ZLIB_VERSION" \
    && CC="$CC" AR="$AR" RANLIB="$RANLIB" CFLAGS="-Os" ./configure --static --prefix="$ZDIR" \
    && make -j"$(nproc)" && make install) > "$PROJ/build/zlib-build.log" 2>&1 \
    || { tail -30 "$PROJ/build/zlib-build.log"; exit 1; }
echo "zlib installed in $ZDIR: $(ls "$ZDIR/lib" | tr '\n' ' ')"

# 1. mbedTLS (static library). The kernel of the device (2.6.28) has no getrandom(), and mbedTLS
#    would then read the blocking /dev/random and hang; see apps/curl/mbedtls-urandom.h.
fetch "https://github.com/Mbed-TLS/mbedtls/releases/download/mbedtls-$MBEDTLS_VERSION/mbedtls-$MBEDTLS_VERSION.tar.bz2" "mbedtls-$MBEDTLS_VERSION.tar.bz2"
rm -rf "$SRCDIR/mbedtls-$MBEDTLS_VERSION" "$DEPS"
tar -C "$SRCDIR" -xjf "$DL/mbedtls-$MBEDTLS_VERSION.tar.bz2"
make -C "$SRCDIR/mbedtls-$MBEDTLS_VERSION" -j"$(nproc)" lib \
    CC="$CC" AR="$AR" RANLIB="$RANLIB" \
    CFLAGS="-Os -include $PROJ/apps/curl/mbedtls-urandom.h" > "$PROJ/build/mbedtls-build.log" 2>&1 \
    || { tail -30 "$PROJ/build/mbedtls-build.log"; exit 1; }
# Manual install: "make install" would also try to build the example programs, and the linker
# then trips over our cross-built libraries. The static libraries and headers are all we need.
MBED="$DEPS/usr/local"
# Our private zlib and mbedTLS must win over the sysroot's old zlib (see scripts/maemo-gcc).
export MAEMO_DEPS="$ZDIR:$MBED"
mkdir -p "$MBED/include" "$MBED/lib"
cp -r "$SRCDIR/mbedtls-$MBEDTLS_VERSION/include/mbedtls" "$SRCDIR/mbedtls-$MBEDTLS_VERSION/include/psa" "$MBED/include/"
cp "$SRCDIR/mbedtls-$MBEDTLS_VERSION"/library/libmbed*.a "$MBED/lib/"
echo "mbedTLS installed in $MBED: $(ls "$MBED/lib" | tr '\n' ' ')"

# 2. curl
fetch "https://curl.se/download/curl-$CURL_VERSION.tar.xz" "curl-$CURL_VERSION.tar.xz"
rm -rf "$SRCDIR/curl-$CURL_VERSION" "$OUT"
tar -C "$SRCDIR" -xJf "$DL/curl-$CURL_VERSION.tar.xz"
mkdir -p "$OUT/root" "$PROJ/build/obj/curl-$CURL_VERSION"
cd "$PROJ/build/obj/curl-$CURL_VERSION"
rm -rf ./*

# CA bundle: Mozilla roots as published by curl.se (certifi-style PEM). The date in the file name
# of the cache entry is the download date, refresh it by deleting build/downloads/cacert.pem.
fetch "https://curl.se/ca/cacert.pem" "cacert.pem"
cp "$DL/cacert.pem" "$OUT/cacert.pem"

"$SRCDIR/curl-$CURL_VERSION/configure" \
    --host=arm-linux-gnueabi --build="$(gcc -dumpmachine)" \
    --prefix=/opt/curl \
    --with-mbedtls="$MBED" \
    --with-ca-bundle=/opt/curl/etc/ssl/cacert.pem --without-ca-path \
    --with-zlib="$ZDIR" \
    --enable-static --disable-shared \
    --disable-ldap --disable-ldaps --disable-rtsp --disable-dict --disable-telnet --disable-tftp \
    --disable-pop3 --disable-imap --disable-smtp --disable-gopher --disable-mqtt --disable-manual \
    --without-libpsl --without-brotli --without-zstd --without-libidn2 --without-nghttp2 \
    --without-librtmp --without-libssh2 --without-libssh \
    CC="$CC" AR="$AR" RANLIB="$RANLIB" CFLAGS="-Os" \
    > "$OUT/configure.log" 2>&1 || { tail -40 "$OUT/configure.log"; exit 1; }
make -j"$(nproc)" > "$OUT/make.log" 2>&1 || { grep -E 'error|Error' "$OUT/make.log" | head -20; exit 1; }
make install DESTDIR="$OUT/root" >> "$OUT/make.log" 2>&1

arm-linux-gnueabi-strip -o "$OUT/curl" "$OUT/root/opt/curl/bin/curl"

echo "== Check"
file "$OUT/curl" | cut -c1-140
arm-linux-gnueabi-readelf -d "$OUT/curl" | grep NEEDED
echo -n "Highest glibc symbol: "
arm-linux-gnueabi-objdump -T "$OUT/curl" | grep -oE 'GLIBC_[0-9.]+' | sort -uV | tail -1
ls -l "$OUT/curl" "$OUT/cacert.pem"
