#!/bin/bash
# Cross-build GNU screen for Maemo 5. Run INSIDE the Workshop (make -C apps/screen build).
# Output: /project/build/out/screen-$VERSION/root/opt/screen/{bin,share}
# Uses the plain libncurses5 of the device (the sysroot has the same version 5.7). No PAM, no utmp updates (the phone has no login accounting).
set -euo pipefail

VERSION="${VERSION:-5.0.2}"
PROJ=/project
SR="$PROJ/sysroot"
DL="$PROJ/build/downloads"
SRCDIR="$PROJ/build/src"
OUT="$PROJ/build/out/screen-$VERSION"

[ -d "$SR/usr/include" ] || { echo "Missing sysroot, run: make sysroot"; exit 1; }
mkdir -p "$DL" "$SRCDIR"
f="screen-$VERSION.tar.gz"
[ -s "$DL/$f" ] || curl -fL --retry 3 -o "$DL/$f" "https://ftp.gnu.org/gnu/screen/$f"
echo "sha256 $(sha256sum "$DL/$f" | cut -d' ' -f1)  $f"
rm -rf "$SRCDIR/screen-$VERSION" "$OUT"
tar -C "$SRCDIR" -xzf "$DL/$f"
mkdir -p "$OUT/root"
cd "$SRCDIR/screen-$VERSION"
./configure --host=arm-linux-gnueabi --build="$(gcc -dumpmachine)" --prefix=/opt/screen \
    --disable-pam --disable-socket-dir --enable-colors256 --with-pty-mode=0620 --with-pty-group=5 --with-sys-screenrc=/opt/screen/etc/screenrc \
    CC="$PROJ/scripts/maemo-gcc" CFLAGS="-Os -D_GNU_SOURCE -include $PROJ/scripts/maemo-compat.h" \
    > "$OUT/configure.log" 2>&1 || { tail -30 "$OUT/configure.log"; exit 1; }
make -j"$(nproc)" > "$OUT/make.log" 2>&1 || { grep -E 'error|Error' "$OUT/make.log" | head -20; tail -15 "$OUT/make.log"; exit 1; }
mkdir -p "$OUT/root/opt/screen/bin" "$OUT/root/opt/screen/etc"
arm-linux-gnueabi-strip -o "$OUT/root/opt/screen/bin/screen" screen
cp COPYING "$OUT/COPYING"
BIN="$OUT/root/opt/screen/bin/screen"
echo "== Check"
file "$BIN" | cut -c1-140
arm-linux-gnueabi-readelf -d "$BIN" | grep NEEDED
echo -n "Highest glibc symbol: "
arm-linux-gnueabi-objdump -T "$BIN" | grep -oE 'GLIBC_[0-9.]+' | sort -uV | tail -1
ls -l "$BIN"
