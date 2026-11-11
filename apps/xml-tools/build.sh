#!/bin/bash
# Cross-build xmllint and xsltproc (libxml2 + libxslt, static) for Maemo 5 (armel, glibc 2.5). Run INSIDE the Workshop:
#   make -C apps/xml-tools build      (VERSION = libxml2 version, XSLT_VERSION = libxslt version)
# Output: /project/build/out/xml-tools-$VERSION/{xmllint,xsltproc}   (stripped binaries)
# The device has only libxml2 2.6.32 (no tools); the new library is linked statically, nothing system-wide changes.
set -euo pipefail

VERSION="${VERSION:-2.15.4}"
XSLT_VERSION="${XSLT_VERSION:-1.1.45}"
PROJ=/project
SR="$PROJ/sysroot"
DL="$PROJ/build/downloads"
SRCDIR="$PROJ/build/src"
OUT="$PROJ/build/out/xml-tools-$VERSION"
OBJ="$PROJ/build/obj/xml-tools-$VERSION"
PREFIX="$PROJ/build/deps/libxml2-$VERSION"

[ -d "$SR/usr/include" ] || { echo "Missing sysroot, run: make sysroot"; exit 1; }
mkdir -p "$DL" "$SRCDIR"
fetch() { # name file url
    [ -s "$DL/$2" ] || curl -fL --retry 3 -o "$DL/$2" "$3"
    echo "sha256 $(sha256sum "$DL/$2" | cut -d' ' -f1)  $2"
}
fetch libxml2 "libxml2-$VERSION.tar.xz" "https://download.gnome.org/sources/libxml2/${VERSION%.*}/libxml2-$VERSION.tar.xz"
fetch libxslt "libxslt-$XSLT_VERSION.tar.xz" "https://download.gnome.org/sources/libxslt/${XSLT_VERSION%.*}/libxslt-$XSLT_VERSION.tar.xz"
rm -rf "$SRCDIR/libxml2-$VERSION" "$SRCDIR/libxslt-$XSLT_VERSION" "$OBJ" "$OUT" "$PREFIX"
tar -C "$SRCDIR" -xJf "$DL/libxml2-$VERSION.tar.xz"
tar -C "$SRCDIR" -xJf "$DL/libxslt-$XSLT_VERSION.tar.xz"
mkdir -p "$OBJ/xml" "$OBJ/xslt" "$OUT"

CC="$PROJ/scripts/maemo-gcc"
CFLAGS="-Os -include $PROJ/scripts/maemo-compat.h"
HOST=(--host=arm-linux-gnueabi --build="$(gcc -dumpmachine)")
run() { local log="$1"; shift; "$@" > "$log" 2>&1 || { tail -30 "$log"; exit 1; }; }

# libxml2: no Python, ICU, LZMA, zlib or readline (smaller, no extra dependencies); iconv comes from glibc.
cd "$OBJ/xml"
run "$OUT/configure-xml.log" "$SRCDIR/libxml2-$VERSION/configure" "${HOST[@]}" --prefix="$PREFIX" \
    --disable-shared --enable-static --without-python --without-icu --without-lzma --without-zlib \
    --without-readline --without-history --without-http --without-ftp \
    CC="$CC" CFLAGS="$CFLAGS"
run "$OUT/make-xml.log" make -j"$(nproc)"
run "$OUT/install-xml.log" make install

# libxslt (with EXSLT) against it
cd "$OBJ/xslt"
run "$OUT/configure-xslt.log" "$SRCDIR/libxslt-$XSLT_VERSION/configure" "${HOST[@]}" --prefix="$PREFIX" \
    --disable-shared --enable-static --without-python --without-crypto --without-plugins \
    --with-libxml-prefix="$PREFIX" \
    CC="$CC" CFLAGS="$CFLAGS" PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig" XML_CONFIG="$PREFIX/bin/xml2-config"
run "$OUT/make-xslt.log" make -j"$(nproc)"
run "$OUT/install-xslt.log" make install   # xslt-config and the static library, for xmlstarlet

arm-linux-gnueabi-strip -o "$OUT/xmllint" "$PREFIX/bin/xmllint"
arm-linux-gnueabi-strip -o "$OUT/xsltproc" "$OBJ/xslt/xsltproc/xsltproc"

echo "== Check"
file "$OUT/xmllint" "$OUT/xsltproc" | cut -c1-140
ls -l "$OUT/xmllint" "$OUT/xsltproc"
