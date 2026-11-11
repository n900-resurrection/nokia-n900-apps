#!/bin/bash
# Cross-build irssi (IRC client) for Maemo 5 (armel, glibc 2.5). Run INSIDE the Workshop: make -C apps/irssi build
# Output: /project/build/out/irssi-$VERSION/irssi (stripped), plus the theme/help files in root/
# Links statically: GLib 2.66 (apps/glib2), OpenSSL 3 (apps/openssl, TLS 1.3), ncursesw of the sysroot (UTF-8), so the system libraries are not touched.
set -euo pipefail

VERSION="${VERSION:-1.4.5}"
PROJ=/project
SR="$PROJ/sysroot"
DL="$PROJ/build/downloads"
SRCDIR="$PROJ/build/src"
OUT="$PROJ/build/out/irssi-$VERSION"
OBJ="$PROJ/build/obj/irssi-$VERSION"
GLIB="$PROJ/build/deps/glib2-2.66.8"
SSL="$PROJ/build/deps/openssl-3.5.9"
FFI="$PROJ/build/deps/libffi-3.4.6"
ZLIB="$PROJ/build/deps/zlib-1.3.2"

[ -d "$SR/usr/include" ] || { echo "Missing sysroot, run: make sysroot"; exit 1; }
[ -f "$GLIB/lib/libglib-2.0.a" ] || { echo "Missing GLib, run: make -C apps/glib2 build"; exit 1; }
[ -f "$SSL/lib/libssl.a" ] || { echo "Missing OpenSSL, run: make -C apps/openssl build"; exit 1; }
mkdir -p "$DL" "$SRCDIR"
f="irssi-$VERSION.tar.xz"
[ -s "$DL/$f" ] || curl -fL --retry 3 -o "$DL/$f" "https://github.com/irssi/irssi/releases/download/$VERSION/$f"
echo "sha256 $(sha256sum "$DL/$f" | cut -d' ' -f1)  $f"
rm -rf "$SRCDIR/irssi-$VERSION" "$OBJ" "$OUT"
tar -C "$SRCDIR" -xJf "$DL/$f"
mkdir -p "$OBJ" "$OUT/root"

export MAEMO_DEPS="$GLIB:$SSL:$FFI:$ZLIB"
export PKG_CONFIG_PATH="$GLIB/lib/pkgconfig:$FFI/lib/pkgconfig:$ZLIB/lib/pkgconfig"
cd "$OBJ"
# - --without-perl: no Perl on the phone worth embedding; --without-proxy/otr/socks: not needed.
# - glib and gmodule come from the static GLib; libffi, zlib, pthread, resolv, rt are its static dependencies.
# - -Bstatic is explicit because gold finds the system libglib-2.0.so (2.20) and libssl.so (0.9.8) in the sysroot before our .a files.
# - ncursesw is linked statically (the device has only the plain libncurses5).
"$SRCDIR/irssi-$VERSION/configure" --host=arm-linux-gnueabi --build="$(gcc -dumpmachine)" \
    --prefix=/opt/irssi --sysconfdir=/opt/irssi/etc --without-perl --without-proxy --without-socks --without-otr \
    --without-modules --disable-shared \
    CC="$PROJ/scripts/maemo-gcc" CFLAGS="-Os -D_GNU_SOURCE -include $PROJ/scripts/maemo-compat.h" \
    CPPFLAGS="-I$SR/usr/include/ncursesw -I$SR/usr/include -I$SSL/include" LDFLAGS="-L$GLIB/lib -L$SSL/lib" \
    CURSES_LIBS="-Wl,-Bstatic -lncursesw -Wl,-Bdynamic" \
    OPENSSL_CFLAGS="-I$SSL/include" OPENSSL_LIBS="-L$SSL/lib -Wl,-Bstatic -lssl -lcrypto -Wl,-Bdynamic -lpthread -ldl" \
    > "$OUT/configure.log" 2>&1 || { tail -40 "$OUT/configure.log"; exit 1; }
# automake expanded the link flags into the Makefiles at configure time, and irssi's configure ignores GLIB_LIBS/CURSES_LIBS given to it.
# Replace the -l options with full paths of the static libraries: libtool moves -Wl,-Bstatic to the front of the command line, and gold
# would otherwise pick the system libglib-2.0.so (2.20), libssl.so (0.9.8) and libncursesw.so.5 (missing on the phone) from the sysroot.
find "$OBJ" -name Makefile -exec sed -i \
    -e "s|-lgmodule-2.0 -ldl -lglib-2.0|$GLIB/lib/libgmodule-2.0.a $GLIB/lib/libglib-2.0.a -ldl|" \
    -e "s|-lssl -lcrypto|$SSL/lib/libssl.a $SSL/lib/libcrypto.a|" \
    -e "s|-lncursesw|$SR/usr/lib/libncursesw.a|g" {} +
make -j"$(nproc)" > "$OUT/make.log" 2>&1 || { grep -E 'error|Error' "$OUT/make.log" | head -20; tail -15 "$OUT/make.log"; exit 1; }
make install DESTDIR="$OUT/root" > "$OUT/install.log" 2>&1 || { tail -20 "$OUT/install.log"; exit 1; }
arm-linux-gnueabi-strip -o "$OUT/irssi" "$OUT/root/opt/irssi/bin/irssi"
cp "$SRCDIR/irssi-$VERSION/COPYING" "$OUT/COPYING"
echo "== Check"
file "$OUT/irssi" | cut -c1-140
arm-linux-gnueabi-readelf -d "$OUT/irssi" | grep NEEDED
echo -n "Highest glibc symbol: "
arm-linux-gnueabi-objdump -T "$OUT/irssi" | grep -oE 'GLIBC_[0-9.]+' | sort -uV | tail -1
ls -l "$OUT/irssi"
