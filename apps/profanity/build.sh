#!/bin/bash
# Cross-build Profanity (XMPP client) for Maemo 5 (armel, glibc 2.5). Run INSIDE the Workshop: make -C apps/profanity build
# Output: /project/build/out/profanity-$VERSION/{profanity, root/}
# Links statically: GLib 2.66 (apps/glib2), libstrophe + OpenSSL 3 (apps/libstrophe), libcurl with mbedTLS (apps/curl), SQLite, readline and ncursesw (UTF-8).
# The optional features (OMEMO, OTR, PGP, Python and C plugins, notifications, X screensaver, icons and clipboard, spell checker) are off by default in meson_options.txt.
# Built without OMEMO, OTR, PGP, plugins (Python and C), desktop notifications, spell checker, icons and clipboard (they need libraries the phone does not have).
set -euo pipefail

VERSION="${VERSION:-0.19.0}"
PROJ=/project
SR="$PROJ/sysroot"
DL="$PROJ/build/downloads"
SRCDIR="$PROJ/build/src"
OUT="$PROJ/build/out/profanity-$VERSION"
OBJ="$PROJ/build/obj/profanity-$VERSION"
GLIB="$PROJ/build/deps/glib2-2.66.8"
STROPHE="$PROJ/build/deps/libstrophe-0.14.0"
SQLITE="$PROJ/build/deps/sqlite-3500400"
READLINE="$PROJ/build/deps/readline-8.2"
FFI="$PROJ/build/deps/libffi-3.4.6"
ZLIB="$PROJ/build/deps/zlib-1.3.2"
CURL="$PROJ/build/out/curl-8.23.0/root/opt/curl"
MBED="$PROJ/build/deps/mbedtls-3.6.7/usr/local"
SSL="$PROJ/build/deps/openssl-3.5.9"

[ -d "$SR/usr/include" ] || { echo "Missing sysroot, run: make sysroot"; exit 1; }
for f in "$GLIB/lib/libglib-2.0.a" "$STROPHE/lib/libstrophe.a" "$CURL/lib/libcurl.a"; do [ -f "$f" ] || { echo "Missing $f (build the dependencies first)"; exit 1; }; done
mkdir -p "$DL" "$SRCDIR"
f="profanity-$VERSION.tar.xz"
[ -s "$DL/$f" ] || curl -fL --retry 3 -o "$DL/$f" "https://github.com/profanity-im/profanity/releases/download/$VERSION/$f"
echo "sha256 $(sha256sum "$DL/$f" | cut -d' ' -f1)  $f"
rm -rf "$SRCDIR/profanity-$VERSION" "$OBJ" "$OUT"
tar -C "$SRCDIR" -xJf "$DL/$f"
mkdir -p "$OBJ/pc" "$OUT/root"

# pkg-config files that the dependencies lack or have with target paths: libcurl (real paths, static mbedTLS), sqlite3 (none at all)
sed -e "s|^prefix=.*|prefix=$CURL|" -e "s|^Libs:.*|Libs: -L\${libdir} -lcurl -L$MBED/lib -lmbedtls -lmbedx509 -lmbedcrypto $ZLIB/lib/libz.a -lrt -pthread|" \
    "$CURL/lib/pkgconfig/libcurl.pc" > "$OBJ/pc/libcurl.pc"
cat > "$OBJ/pc/sqlite3.pc" <<PC
Name: SQLite
Description: SQL database engine
Version: 3.50.4
Cflags: -I$SQLITE/include
Libs: $SQLITE/lib/libsqlite3.a -lm -ldl -lpthread
PC
export PKG_CONFIG_PATH="$OBJ/pc:$GLIB/lib/pkgconfig:$STROPHE/lib/pkgconfig:$READLINE/lib/pkgconfig:$FFI/lib/pkgconfig:$ZLIB/lib/pkgconfig"
export MAEMO_DEPS="$GLIB:$STROPHE:$SQLITE:$READLINE:$FFI:$ZLIB:$SSL:$CURL"

cat > "$OBJ/cross.ini" <<INI
[binaries]
c = '$PROJ/scripts/maemo-gcc'
ar = 'arm-linux-gnueabi-ar'
strip = 'arm-linux-gnueabi-strip'
pkg-config = 'pkg-config'
exe_wrapper = ['qemu-arm', '-L', '$SR']

[host_machine]
system = 'linux'
cpu_family = 'arm'
cpu = 'armv7'
endian = 'little'

[properties]
needs_exe_wrapper = true

[built-in options]
c_args = ['-Os', '-include', '$PROJ/scripts/maemo-compat.h', '-include', '$PROJ/scripts/maemo-endian.h']
pkg_config_path = ['$OBJ/pc', '$GLIB/lib/pkgconfig', '$STROPHE/lib/pkgconfig', '$READLINE/lib/pkgconfig', '$FFI/lib/pkgconfig', '$ZLIB/lib/pkgconfig']
INI

cd "$SRCDIR/profanity-$VERSION"
meson setup "$OBJ/b" --cross-file "$OBJ/cross.ini" --prefix /opt/profanity --sysconfdir /opt/profanity/etc -Dprefer_static=true \
    -Dnotifications=disabled -Dtests=false \
    > "$OBJ/setup.log" 2>&1 || { tail -40 "$OBJ/setup.log"; exit 1; }
ninja -C "$OBJ/b" > "$OUT/ninja.log" 2>&1 || { grep -E "error|FAILED" "$OUT/ninja.log" | head -20; tail -6 "$OUT/ninja.log"; exit 1; }
DESTDIR="$OUT/root" ninja -C "$OBJ/b" install > "$OUT/install.log" 2>&1 || { tail -20 "$OUT/install.log"; exit 1; }
arm-linux-gnueabi-strip -o "$OUT/profanity" "$OUT/root/opt/profanity/bin/profanity"
cp "$SRCDIR/profanity-$VERSION/COPYING" "$OUT/COPYING"
echo "== Check"
file "$OUT/profanity" | cut -c1-140
arm-linux-gnueabi-readelf -d "$OUT/profanity" | grep NEEDED
echo -n "Highest glibc symbol: "
arm-linux-gnueabi-objdump -T "$OUT/profanity" | grep -oE 'GLIBC_[0-9.]+' | sort -uV | tail -1
ls -l "$OUT/profanity"
