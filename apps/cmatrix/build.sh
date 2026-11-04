#!/bin/bash
# Cross-build cmatrix for Maemo 5 (armel, glibc 2.5). Run INSIDE the Workshop:
#   workshop exec n900 -- bash -c 'VERSION=2.0 /project/apps/cmatrix/build.sh'   (or: make -C apps/cmatrix build)
# Output: /project/build/out/cmatrix-$VERSION/cmatrix (stripped binary)
#
# cmatrix uses plain ncurses (no wide characters), so it is linked DYNAMICALLY against the
# libncurses5 that the device already has (the sysroot has the same version, 5.7).
set -euo pipefail

VERSION="${VERSION:-2.0}"
PROJ=/project
SRC="$PROJ/build/upstream/cmatrix"
OUT="$PROJ/build/out/cmatrix-$VERSION"

[ -d "$PROJ/sysroot/usr/include" ] || { echo "Missing sysroot, run: make sysroot"; exit 1; }

# 1. Sources (upstream tag v$VERSION)
if [ ! -d "$SRC/.git" ]; then
    mkdir -p "$(dirname "$SRC")"
    git clone -q https://github.com/abishekvashok/cmatrix.git "$SRC"
fi
git -C "$SRC" fetch -q --tags
git -C "$SRC" checkout -q -f "v$VERSION"

# 2. Build. One source file. The definitions below are what the upstream CMakeLists.txt and
#    configure.ac would detect; ncurses 5.7 has use_default_colors, resizeterm and wresize.
#    No console font support (setfont/consolechars), which does not exist on Maemo 5.
rm -rf "$OUT"; mkdir -p "$OUT"
"$PROJ/scripts/maemo-gcc" -Os -Wall -o "$OUT/cmatrix.unstripped" "$SRC/cmatrix.c" \
    -DEXCLUDE_CONFIG_H "-DVERSION=\"$VERSION\"" -DUSE_TIOCSTI \
    -DHAVE_NCURSES_H -DHAVE_SYS_IOCTL_H -DHAVE_UNISTD_H -DHAVE_TERMIOS_H \
    -DHAVE_USE_DEFAULT_COLORS -DHAVE_RESIZETERM -DHAVE_WRESIZE \
    -lncurses
arm-linux-gnueabi-strip -o "$OUT/cmatrix" "$OUT/cmatrix.unstripped"
rm "$OUT/cmatrix.unstripped"

echo "== Check"
file "$OUT/cmatrix" | cut -c1-140
arm-linux-gnueabi-readelf -d "$OUT/cmatrix" | grep NEEDED
echo -n "Highest glibc symbol: "
arm-linux-gnueabi-objdump -T "$OUT/cmatrix" | grep -oE 'GLIBC_[0-9.]+' | sort -uV | tail -1
ls -l "$OUT/cmatrix"
