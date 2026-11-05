#!/bin/bash
# Cross-build BusyBox 1.37 for Maemo 5 (armel, glibc 2.5). Run INSIDE the Workshop:
#   workshop exec n900 -- bash -c 'VERSION=1.37.0 /project/apps/busybox/build.sh'   (or: make -C apps/busybox build)
# Output: /project/build/out/busybox-$VERSION/busybox   (stripped, dynamic, links the system glibc 2.5)
#
# The device has busybox-power 1.23.1 as /bin/busybox. This one is installed in /opt/busybox and
# never replaces it. Dynamic, like the system busybox: DNS and user lookups (NSS) need the shared glibc.
# Configuration: upstream defconfig plus the changes in apps/busybox/config.sh.
set -euo pipefail

VERSION="${VERSION:-1.37.0}"
PROJ=/project
SR="$PROJ/sysroot"
DL="$PROJ/build/downloads"
SRCDIR="$PROJ/build/src"
OUT="$PROJ/build/out/busybox-$VERSION"
OBJ="$PROJ/build/obj/busybox-$VERSION"

[ -d "$SR/usr/include" ] || { echo "Missing sysroot, run: make sysroot"; exit 1; }
mkdir -p "$DL" "$SRCDIR"
f="busybox-$VERSION.tar.bz2"
[ -s "$DL/$f" ] || curl -fL --retry 3 -o "$DL/$f" "https://busybox.net/downloads/$f"
echo "sha256 $(sha256sum "$DL/$f" | cut -d' ' -f1)  $f"
rm -rf "$SRCDIR/busybox-$VERSION" "$OBJ" "$OUT"
tar -C "$SRCDIR" -xjf "$DL/$f"
mkdir -p "$OBJ" "$OUT"

# Shims for functions that glibc 2.5 lacks (see shims.c); linked via CONFIG_EXTRA_LDLIBS.
"$PROJ/scripts/maemo-gcc" -Os -c "$PROJ/apps/busybox/shims.c" -o "$OBJ/shims.o"
arm-linux-gnueabi-ar rcs "$PROJ/build/obj/busybox-shims.a" "$OBJ/shims.o"

M=(make -C "$SRCDIR/busybox-$VERSION" O="$OBJ" ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- \
   CC="$PROJ/scripts/maemo-gcc" HOSTCC=gcc)
"${M[@]}" defconfig > "$OUT/config.log" 2>&1
"$PROJ/apps/busybox/config.sh" "$OBJ/.config"
"${M[@]}" oldconfig < /dev/null >> "$OUT/config.log" 2>&1 || true
"${M[@]}" -j"$(nproc)" > "$OUT/make.log" 2>&1 \
    || { grep -E 'error|Error' "$OUT/make.log" | head -20; exit 1; }
arm-linux-gnueabi-strip -o "$OUT/busybox" "$OBJ/busybox"

echo "== Check"
file "$OUT/busybox" | cut -c1-140
ls -l "$OUT/busybox"
echo "applets: $("$OBJ/busybox_unstripped" 2>/dev/null | head -0; grep -c '^CONFIG_.*=y' "$OBJ/.config") options on"
