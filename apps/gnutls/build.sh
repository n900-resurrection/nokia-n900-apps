#!/bin/bash
# Cross-build GnuTLS 3.8 and its libraries (GMP, Nettle, libtasn1, libgpg-error, libgcrypt) as static libraries for Maemo 5 (armel, glibc 2.5).
# Run INSIDE the Workshop:  make -C apps/gnutls build
#
# Why: WeeChat needs GnuTLS (TLS 1.2/1.3 for IRC) and libgcrypt; the phone has neither. Everything goes into one prefix:
# /project/build/deps/gnutls-$VERSION/{include,lib}  (use with PKG_CONFIG_PATH=$PREFIX/lib/pkgconfig and MAEMO_DEPS).
# The CA bundle of the curl package is the default trust store of GnuTLS (/opt/curl/etc/ssl/cacert.pem).
# Built with -fPIC (WeeChat plugins are shared modules). No assembler code anywhere (GMP, Nettle, libgcrypt, GnuTLS): slower, but it builds the same way with the sysroot compiler; no p11-kit, no tools.
set -euo pipefail

VERSION="${VERSION:-3.8.13}"
PROJ=/project
SR="$PROJ/sysroot"
DL="$PROJ/build/downloads"
SRCDIR="$PROJ/build/src"
PREFIX="$PROJ/build/deps/gnutls-$VERSION"
OBJ="$PROJ/build/obj/gnutls-$VERSION"
LOG="$OBJ/logs"

[ -d "$SR/usr/include" ] || { echo "Missing sysroot, run: make sysroot"; exit 1; }
mkdir -p "$DL" "$SRCDIR" "$LOG"
# ONLY=<directory name> rebuilds just that library into the existing prefix (e.g. ONLY=gnutls-3.8.13)
[ -n "${ONLY:-}" ] || rm -rf "$PREFIX"
export MAEMO_DEPS="$PREFIX"
export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig"
HOST=(--host=arm-linux-gnueabi --build="$(gcc -dumpmachine)")
COMMON=(--prefix="$PREFIX" --disable-shared --enable-static --disable-nls --disable-doc)
CC="$PROJ/scripts/maemo-gcc"
CFLAGS="-Os -fPIC -include $PROJ/scripts/maemo-compat.h"   # -fPIC: WeeChat links these static libraries into its plugin modules (.so)

# build NAME-VERSION URL-PREFIX EXTENSION -- configure arguments
build() {
    local dir=$1 url=$2; shift 2
    [ -z "${ONLY:-}" ] || [ "$ONLY" = "$dir" ] || return 0
    local f="${url##*/}"
    [ -s "$DL/$f" ] || curl -fL --retry 3 -o "$DL/$f" "$url"
    echo "sha256 $(sha256sum "$DL/$f" | cut -d' ' -f1)  $f"
    rm -rf "$SRCDIR/$dir" "$OBJ/$dir"
    tar -C "$SRCDIR" -xf "$DL/$f"
    mkdir -p "$OBJ/$dir"; cd "$OBJ/$dir"
    "$SRCDIR/$dir/configure" "${HOST[@]}" "${COMMON[@]}" "$@" CC="$CC" CFLAGS="$CFLAGS" CC_FOR_BUILD=gcc \
        CPPFLAGS="-I$PREFIX/include" LDFLAGS="-L$PREFIX/lib" > "$LOG/$dir-configure.log" 2>&1 || { tail -30 "$LOG/$dir-configure.log"; exit 1; }
    make -j"$(nproc)" > "$LOG/$dir-make.log" 2>&1 || { grep -E "error|Error" "$LOG/$dir-make.log" | head -15; tail -5 "$LOG/$dir-make.log"; exit 1; }
    make install > "$LOG/$dir-install.log" 2>&1 || { tail -15 "$LOG/$dir-install.log"; exit 1; }
    echo "built $dir"
}

build gmp-6.3.0 https://ftp.gnu.org/gnu/gmp/gmp-6.3.0.tar.xz --disable-assembly --disable-cxx
build nettle-3.10.1 https://ftp.gnu.org/gnu/nettle/nettle-3.10.1.tar.gz --disable-assembler --disable-documentation --disable-openssl \
    --with-include-path="$PREFIX/include" --with-lib-path="$PREFIX/lib"
build libtasn1-4.20.0 https://ftp.gnu.org/gnu/libtasn1/libtasn1-4.20.0.tar.gz --disable-gcc-warnings
build libgpg-error-1.51 https://www.gnupg.org/ftp/gcrypt/libgpg-error/libgpg-error-1.51.tar.bz2 --disable-tests --disable-languages
export PATH="$PREFIX/bin:$PATH"
build libgcrypt-1.11.0 https://www.gnupg.org/ftp/gcrypt/libgcrypt/libgcrypt-1.11.0.tar.bz2 --disable-asm --disable-padlock-support --disable-amd64-as-feature-detection \
    --with-libgpg-error-prefix="$PREFIX"
build gnutls-3.8.13 https://www.gnupg.org/ftp/gcrypt/gnutls/v3.8/gnutls-3.8.13.tar.xz --without-p11-kit --with-included-unistring --without-idn \
    --disable-tests --disable-tools --disable-cxx --disable-libdane --disable-guile --without-tpm --without-tpm2 --disable-hardware-acceleration \
    --with-default-trust-store-file=/opt/curl/etc/ssl/cacert.pem --disable-openssl-compatibility --disable-full-test-suite --disable-valgrind-tests --disable-gtk-doc-html
echo "== Check"
ls -l "$PREFIX/lib"/*.a
pkg-config --modversion gnutls libgcrypt nettle gmp 2>&1 | tr '\n' ' '
