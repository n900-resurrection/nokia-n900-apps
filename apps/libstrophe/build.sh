#!/bin/bash
# Cross-build libstrophe (XMPP client library) as a static library for Maemo 5 (armel, glibc 2.5). Run INSIDE the Workshop: make -C apps/libstrophe build
# Output: /project/build/deps/libstrophe-$VERSION/{include,lib}   (first user: Profanity)
# TLS: OpenSSL 3 (apps/openssl, TLS 1.2/1.3), XML: expat of the sysroot, both given as full paths of the static libraries (the sysroot also has the old
# libssl.so 0.9.8, which gold would otherwise prefer).
set -euo pipefail

VERSION="${VERSION:-0.14.0}"
PROJ=/project
SR="$PROJ/sysroot"
DL="$PROJ/build/downloads"
SRCDIR="$PROJ/build/src"
OBJ="$PROJ/build/obj/libstrophe-$VERSION"
PREFIX="$PROJ/build/deps/libstrophe-$VERSION"
SSL="$PROJ/build/deps/openssl-3.5.9"

[ -f "$SSL/lib/libssl.a" ] || { echo "Missing OpenSSL, run: make -C apps/openssl build"; exit 1; }
mkdir -p "$DL" "$SRCDIR"
f="libstrophe-$VERSION.tar.gz"
[ -s "$DL/$f" ] || curl -fL --retry 3 -o "$DL/$f" "https://github.com/strophe/libstrophe/releases/download/$VERSION/$f"
echo "sha256 $(sha256sum "$DL/$f" | cut -d' ' -f1)  $f"
rm -rf "$SRCDIR/libstrophe-$VERSION" "$OBJ" "$PREFIX"
tar -C "$SRCDIR" -xzf "$DL/$f"
mkdir -p "$OBJ"; cd "$OBJ"
# - getrandom is off: the kernel 2.6.28 has no such system call (libstrophe falls back to the C library).
# - zlib (stream compression) and c-ares are off.
"$SRCDIR/libstrophe-$VERSION/configure" --host=arm-linux-gnueabi --build="$(gcc -dumpmachine)" --prefix="$PREFIX" \
    --disable-shared --enable-static --disable-examples --enable-tls --disable-getrandom --disable-zlib --disable-cares \
    CC="$PROJ/scripts/maemo-gcc" CFLAGS="-Os -include $PROJ/scripts/maemo-compat.h" \
    CPPFLAGS="-I$SSL/include -I$SR/usr/include" \
    openssl_CFLAGS="-I$SSL/include" openssl_LIBS="$SSL/lib/libssl.a $SSL/lib/libcrypto.a -ldl -lpthread" \
    expat_CFLAGS="-I$SR/usr/include" expat_LIBS="$SR/usr/lib/libexpat.a" \
    > "$OBJ/configure.log" 2>&1 || { tail -30 "$OBJ/configure.log"; exit 1; }
make -j"$(nproc)" > "$OBJ/make.log" 2>&1 || { grep -E "error|Error" "$OBJ/make.log" | head -15; tail -5 "$OBJ/make.log"; exit 1; }
make install > "$OBJ/install.log" 2>&1 || { tail -15 "$OBJ/install.log"; exit 1; }
# libstrophe has external functions named tls_free, tls_new, ... which clash with the symbols of libssl.a in a static link (multiple definition of tls_free):
# rename all of them (definitions and references) inside the archive.
arm-linux-gnueabi-nm --defined-only -g "$PREFIX/lib/libstrophe.a" 2>/dev/null | awk '$2 ~ /^[TDBR]$/ && $3 ~ /^tls_/ {print $3, "strophe_" $3}' | sort -u > "$OBJ/rename.txt"
echo "renamed symbols: $(wc -l < "$OBJ/rename.txt")"
arm-linux-gnueabi-objcopy --redefine-syms="$OBJ/rename.txt" "$PREFIX/lib/libstrophe.a"
# the .pc file: no Requires.private (there is no expat.pc and openssl.pc for the target), the private libraries as full paths of the static libraries (what a program linking libstrophe.a needs)
sed -i -e "/^Requires.private:/d" -e "s|^Libs.private:.*|Libs.private: $SSL/lib/libssl.a $SSL/lib/libcrypto.a $SR/usr/lib/libexpat.a -lresolv -ldl -lpthread|" "$PREFIX/lib/pkgconfig/libstrophe.pc"
echo "== Check"
ls -l "$PREFIX/lib/libstrophe.a"
grep -E "^(Version|Libs)" "$PREFIX/lib/pkgconfig/libstrophe.pc"
