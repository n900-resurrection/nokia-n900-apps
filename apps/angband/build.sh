#!/bin/bash
# Cross-build Angband 4.2.6 (the classic Tolkien roguelike, GPL-2.0, ncurses interface) for Maemo 5. Run INSIDE the Workshop:
#   workshop exec n900 -- bash -c 'VERSION=4.2.6 /project/apps/angband/build.sh'   (or: make -C apps/angband build)
# Output: /project/build/out/angband-$VERSION/root/opt/angband/{bin/angband,share/angband}
#
# NOT TRIED YET (prepared 2026-11-23 to be built on the desktop): the simplest of the prepared ports (C, ncurses of the sysroot); expect a configure option or two.
# Terminal only (--enable-curses): no X11, SDL, sound. It links the libncurses.so.5 of the phone. The tarball of GitHub has no configure: autogen.sh runs autoreconf
# (autoconf, automake, libtool are in the Workshop). Saves and scores go to the home folder of the user (~/.angband), not to the installation.
set -euo pipefail

VERSION="${VERSION:-4.2.6}"
PROJ=/project
SR="$PROJ/sysroot"
DL="$PROJ/build/downloads"
SRCDIR="$PROJ/build/src"
OUT="$PROJ/build/out/angband-$VERSION"

[ -f "$SR/usr/include/ncurses/curses.h" ] || [ -f "$SR/usr/include/curses.h" ] || { echo "Missing the ncurses headers in the sysroot, run: make sysroot"; exit 1; }
mkdir -p "$DL" "$SRCDIR"
f="angband-$VERSION.tar.gz"
[ -s "$DL/$f" ] || curl -fL --retry 3 -o "$DL/$f" "https://github.com/angband/angband/archive/refs/tags/$VERSION.tar.gz"
echo "sha256 $(sha256sum "$DL/$f" | cut -d' ' -f1)  $f"
rm -rf "$SRCDIR/angband-$VERSION" "$OUT"
mkdir -p "$SRCDIR/angband-$VERSION" "$OUT/root"
tar -C "$SRCDIR/angband-$VERSION" --strip-components=1 -xzf "$DL/$f"
cd "$SRCDIR/angband-$VERSION"
./autogen.sh > "$OUT/autogen.log" 2>&1 || { tail -20 "$OUT/autogen.log"; exit 1; }
INC="-I$SR/usr/include"; [ -d "$SR/usr/include/ncurses" ] && INC="-I$SR/usr/include/ncurses $INC"
./configure --host=arm-linux-gnueabi --build="$(gcc -dumpmachine)" --prefix=/opt/angband --bindir=/opt/angband/bin --datarootdir=/opt/angband/share \
    --enable-curses --disable-x11 --disable-sdl --disable-sdl2 --disable-sdl-mixer --disable-sdl2-mixer --disable-test --disable-spoil --without-sphinx \
    CC="$PROJ/scripts/maemo-gcc" CFLAGS="-O2 -include $PROJ/scripts/maemo-compat.h $INC" CPPFLAGS="$INC" LDFLAGS="-L$SR/usr/lib" \
    NCURSES_CFLAGS="$INC" NCURSES_LIBS="-lncurses" \
    > "$OUT/configure.log" 2>&1 || { tail -30 "$OUT/configure.log"; exit 1; }
make -j"$(nproc)" > "$OUT/make.log" 2>&1 || { grep -E 'error|Error' "$OUT/make.log" | head -20; tail -15 "$OUT/make.log"; exit 1; }
make DESTDIR="$OUT/root" install > "$OUT/install.log" 2>&1 || { tail -15 "$OUT/install.log"; exit 1; }
ROOT="$OUT/root/opt/angband"
arm-linux-gnueabi-strip --strip-unneeded "$ROOT/bin/angband"
cp COPYING "$OUT/COPYING" 2>/dev/null || cp docs/copying.rst "$OUT/COPYING"
echo "== Check"
find "$ROOT" -maxdepth 3 -type d | sed "s|$OUT/root||" | head
file "$ROOT/bin/angband" | cut -c1-140
arm-linux-gnueabi-readelf -d "$ROOT/bin/angband" | grep -E "NEEDED|RPATH|RUNPATH"
echo -n "Highest glibc symbol: "
arm-linux-gnueabi-objdump -T "$ROOT/bin/angband" | grep -oE 'GLIBC_[0-9.]+' | sort -uV | tail -1
ls -l "$ROOT/bin/angband"; du -sh "$ROOT/share"
