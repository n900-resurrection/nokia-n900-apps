#!/bin/bash
# Cross-build Midnight Commander (mc) for Maemo 5 (armel, glibc 2.5). Run INSIDE the Workshop: make -C apps/mc build
# Output: /project/build/out/mc-$VERSION/{mc,root/}
# Links statically: GLib 2.66 (apps/glib2) and ncursesw of the sysroot (UTF-8); the system GLib 2.20 is not used.
set -euo pipefail

VERSION="${VERSION:-4.8.33}"
PROJ=/project
SR="$PROJ/sysroot"
DL="$PROJ/build/downloads"
SRCDIR="$PROJ/build/src"
OUT="$PROJ/build/out/mc-$VERSION"
OBJ="$PROJ/build/obj/mc-$VERSION"
GLIB="$PROJ/build/deps/glib2-2.66.8"
FFI="$PROJ/build/deps/libffi-3.4.6"
ZLIB="$PROJ/build/deps/zlib-1.3.2"

[ -d "$SR/usr/include" ] || { echo "Missing sysroot, run: make sysroot"; exit 1; }
[ -f "$GLIB/lib/libglib-2.0.a" ] || { echo "Missing GLib, run: make -C apps/glib2 build"; exit 1; }
mkdir -p "$DL" "$SRCDIR"
f="mc-$VERSION.tar.xz"
[ -s "$DL/$f" ] || curl -fL --retry 3 -o "$DL/$f" "http://ftp.midnight-commander.org/$f"
echo "sha256 $(sha256sum "$DL/$f" | cut -d' ' -f1)  $f"
rm -rf "$SRCDIR/mc-$VERSION" "$OBJ" "$OUT"
tar -C "$SRCDIR" -xJf "$DL/$f"
mkdir -p "$OBJ" "$OUT/root"

export MAEMO_DEPS="$GLIB:$FFI:$ZLIB"
export PKG_CONFIG_PATH="$GLIB/lib/pkgconfig:$FFI/lib/pkgconfig:$ZLIB/lib/pkgconfig"
cd "$OBJ"
# - ncursesw (UTF-8) instead of slang; no X11, GPM, SFTP (libssh2), aspell, NLS and docs.
"$SRCDIR/mc-$VERSION/configure" --host=arm-linux-gnueabi --build="$(gcc -dumpmachine)" \
    --prefix=/opt/mc --sysconfdir=/opt/mc/etc --with-screen=ncursesw --without-x --without-gpm-mouse \
    --disable-vfs-sftp --disable-aspell --disable-nls --disable-doxygen-doc --disable-silent-rules \
    CC="$PROJ/scripts/maemo-gcc" CFLAGS="-Os -D_GNU_SOURCE -include $PROJ/scripts/maemo-compat.h" \
    CPPFLAGS="-I$SR/usr/include/ncursesw -I$SR/usr/include" LDFLAGS="-L$GLIB/lib" \
    > "$OUT/configure.log" 2>&1 || { tail -40 "$OUT/configure.log"; exit 1; }
# libtool drops the -l options that come from its .la files, and gold would pick the system libglib-2.0.so (2.20) and libncursesw.so.5
# (not on the phone) from the sysroot: put the full paths of the static libraries on the make command line (LIBS ends up last).
LINKLIBS=(LIBS="$GLIB/lib/libgmodule-2.0.a $GLIB/lib/libglib-2.0.a $SR/usr/lib/libncursesw.a -ldl -lpthread -lrt -lutil")
make -j"$(nproc)" "${LINKLIBS[@]}" > "$OUT/make.log" 2>&1 || { grep -E 'error|Error' "$OUT/make.log" | head -20; tail -15 "$OUT/make.log"; exit 1; }
make install "${LINKLIBS[@]}" DESTDIR="$OUT/root" > "$OUT/install.log" 2>&1 || { tail -20 "$OUT/install.log"; exit 1; }
# libmc.la records -lncursesw and -lglib-2.0 as dependencies, which gold resolves to the system .so files (and `make install` relinks
# mc with them): drop them from the .la files (the static libraries are given in LIBS) and link mc once more. The stripped result
# is taken from this link, not from the installed copy.
find "$OBJ" -name '*.la' -exec sed -i -e "s| -lncursesw||g" -e "s| -lgmodule-2.0||g" -e "s| -lglib-2.0||g" {} +
rm -f "$OBJ/src/mc" "$OBJ/src/.libs/mc"
make -C "$OBJ/src" "${LINKLIBS[@]}" mc >> "$OUT/make.log" 2>&1 || { tail -15 "$OUT/make.log"; exit 1; }
arm-linux-gnueabi-strip -o "$OUT/mc" "$OBJ/src/mc"
cp "$SRCDIR/mc-$VERSION/COPYING" "$OUT/COPYING"
echo "== Check"
file "$OUT/mc" | cut -c1-140
arm-linux-gnueabi-readelf -d "$OUT/mc" | grep NEEDED
echo -n "Highest glibc symbol: "
arm-linux-gnueabi-objdump -T "$OUT/mc" | grep -oE 'GLIBC_[0-9.]+' | sort -uV | tail -1
ls -l "$OUT/mc"
