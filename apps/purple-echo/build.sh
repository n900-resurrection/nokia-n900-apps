#!/bin/bash
# Cross-build the echo protocol plugin for libpurple 2.7.7. Run INSIDE the Workshop (make -C apps/purple-echo build).
# Output: /project/build/out/purple-echo-$VERSION/libecho.so
# libpurple is not in the sysroot: only its headers are needed (taken from the pidgin 2.7.7 source). The plugin is not linked with
# libpurple; its symbols are resolved when haze/pidgin load it.
set -euo pipefail

VERSION="${VERSION:-0.1}"
PROJ=/project
SR="$PROJ/sysroot"
DL="$PROJ/build/downloads"
SRCDIR="$PROJ/build/src"
OUT="$PROJ/build/out/purple-echo-$VERSION"
PV=2.7.7

[ -d "$SR/usr/include" ] || { echo "Missing sysroot, run: make sysroot"; exit 1; }
mkdir -p "$DL" "$SRCDIR" "$OUT"
f="pidgin-$PV.tar.bz2"
[ -s "$DL/$f" ] || curl -fL --retry 3 -o "$DL/$f" "https://sourceforge.net/projects/pidgin/files/Pidgin/$PV/$f/download"
echo "sha256 $(sha256sum "$DL/$f" | cut -d' ' -f1)  $f"
if [ ! -f "$SRCDIR/pidgin-$PV/libpurple/version.h" ]; then
    tar -C "$SRCDIR" -xjf "$DL/$f" "pidgin-$PV/libpurple" "pidgin-$PV/COPYING"
fi
P="$SRCDIR/pidgin-$PV/libpurple"
"$PROJ/scripts/maemo-gcc" -shared -fPIC -Os -Wall -D_GNU_SOURCE \
    -I"$P" -I"$SR/usr/include/glib-2.0" -I"$SR/usr/lib/glib-2.0/include" \
    -o "$OUT/libecho.so" "$PROJ/apps/purple-echo/echo.c" -lglib-2.0 2>&1 | tee "$OUT/build.log"
arm-linux-gnueabi-strip --strip-unneeded "$OUT/libecho.so"
cp "$SRCDIR/pidgin-$PV/COPYING" "$OUT/COPYING"
echo "== Check"
file "$OUT/libecho.so" | cut -c1-140
arm-linux-gnueabi-nm -D "$OUT/libecho.so" | grep -E " T purple_init_plugin| U (serv_got_im|purple_connection_set_state)"
echo -n "Highest glibc symbol: "
arm-linux-gnueabi-objdump -T "$OUT/libecho.so" | grep -oE 'GLIBC_[0-9.]+' | sort -uV | tail -1
ls -l "$OUT/libecho.so"
