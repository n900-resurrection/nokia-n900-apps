#!/bin/bash
# Cross-build htop for Maemo 5 (armel, glibc 2.5). Run INSIDE the Workshop:
#   workshop exec n900 -- bash -c 'VERSION=3.5.3 /project/apps/htop/build.sh'
# Output: /project/build/out/htop-$VERSION/htop   (stripped binary)
#         /project/build/out/htop-$VERSION/root/  (installed tree)
#
# Note: the device ships htop 0.8.3 (package htop 0.8.3-1maemo5, /opt/maemo/usr/bin/htop). The
# build is installed under /opt/htop3 and packaged as a separate package "htop3" (see package.sh),
# so the system htop stays untouched. Verified 2026-11-04: 3.5.3 starts and draws its UI on a
# real N900.
set -euo pipefail

VERSION="${VERSION:-3.5.3}"
PROJ=/project
SR="$PROJ/sysroot"
SRC="$PROJ/build/upstream/htop"
OUT="$PROJ/build/out/htop-$VERSION"
OBJ="$PROJ/build/obj/htop-$VERSION"

[ -d "$SR/usr/include" ] || { echo "Missing sysroot, run: make sysroot"; exit 1; }

# 1. Sources + autotools (the upstream repository has no generated configure script)
if [ ! -d "$SRC/.git" ]; then
    mkdir -p "$(dirname "$SRC")"
    git clone -q https://github.com/htop-dev/htop.git "$SRC"
fi
git -C "$SRC" checkout -q -f "$VERSION"
git -C "$SRC" clean -fdxq
command -v autoreconf >/dev/null || sudo apt-get install -y autoconf automake libtool
(cd "$SRC" && ./autogen.sh >/dev/null)

# 2. pkg-config file for ncursesw (the sysroot ships no .pc files). The library is linked
#    STATICALLY: the device only has libncurses5 (no wide-character variant).
PC="$PROJ/build/pc"
mkdir -p "$PC"
cat > "$PC/ncursesw.pc" <<EOF
Name: ncursesw
Description: ncursesw from the Fremantle SDK sysroot
Version: 5.7
Cflags: -I$SR/usr/include/ncursesw -I$SR/usr/include
Libs: -L$SR/usr/lib -Wl,-Bstatic -lncursesw -Wl,-Bdynamic
EOF

# 3. Configure and build out of tree.
#    compat.h supplies O_CLOEXEC, which the glibc 2.5 headers lack (the 2.6.28 kernel has it).
rm -rf "$OBJ" "$OUT"
mkdir -p "$OBJ" "$OUT/root"
cd "$OBJ"
export PKG_CONFIG_PATH="$PC" PKG_CONFIG_LIBDIR="$PC"
"$SRC/configure" \
    --host=arm-linux-gnueabi --build="$(gcc -dumpmachine)" \
    --prefix=/opt/htop3 \
    --enable-unicode \
    --disable-hwloc --disable-sensors --disable-capabilities --disable-delayacct \
    CC="$PROJ/scripts/maemo-gcc" \
    CFLAGS="-Os -include $PROJ/apps/htop/compat.h" \
    > "$OUT/configure.log" 2>&1 || { tail -30 "$OUT/configure.log"; exit 1; }
make -j"$(nproc)" > "$OUT/make.log" 2>&1 || { grep -E 'error|Error' "$OUT/make.log" | head -20; exit 1; }
make install DESTDIR="$OUT/root" >> "$OUT/make.log" 2>&1

BIN="$OUT/root/opt/htop3/bin/htop"
arm-linux-gnueabi-strip -o "$OUT/htop" "$BIN"

echo "== Check"
file "$OUT/htop" | cut -c1-140
arm-linux-gnueabi-readelf -d "$OUT/htop" | grep NEEDED
echo -n "Highest glibc symbol: "
arm-linux-gnueabi-objdump -T "$OUT/htop" | grep -oE 'GLIBC_[0-9.]+' | sort -uV | tail -1
ls -l "$OUT/htop"
