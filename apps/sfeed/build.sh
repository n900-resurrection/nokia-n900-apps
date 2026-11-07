#!/bin/bash
# Cross-build sfeed (RSS/Atom feed reader made of small tools) for Maemo 5. Run INSIDE the Workshop:
#   workshop exec n900 -- bash -c 'VERSION=2.4 /project/apps/sfeed/build.sh'   (or: make -C apps/sfeed build)
# Output: /project/build/out/sfeed-$VERSION/root/opt/sfeed/{bin,share}   (installed tree)
#
# sfeed has no dependencies except libc and (for sfeed_curses) the plain ncurses of the device.
# The feeds are downloaded by sfeed_update with curl (package curl), so TLS 1.3 comes from there.
set -euo pipefail

VERSION="${VERSION:-2.4}"
PROJ=/project
SR="$PROJ/sysroot"
DL="$PROJ/build/downloads"
SRCDIR="$PROJ/build/src"
OUT="$PROJ/build/out/sfeed-$VERSION"

[ -d "$SR/usr/include" ] || { echo "Missing sysroot, run: make sysroot"; exit 1; }
mkdir -p "$DL" "$SRCDIR"
f="sfeed-$VERSION.tar.gz"
[ -s "$DL/$f" ] || curl -fL --retry 3 -o "$DL/$f" "https://codemadness.org/releases/sfeed/$f"
echo "sha256 $(sha256sum "$DL/$f" | cut -d' ' -f1)  $f"
rm -rf "$SRCDIR/sfeed-$VERSION" "$OUT"
tar -C "$SRCDIR" -xzf "$DL/$f"
mkdir -p "$OUT/root"
cd "$SRCDIR/sfeed-$VERSION"

# sfeed_update downloads the feeds in parallel with `xargs -P`, which the busybox 1.23 of the phone does not have
# ("xargs: invalid option -- P": no feed was ever downloaded and sfeed_curses closed at once). The feeds are fetched one by one.
grep -q 'xargs -x -0 -P "${maxjobs}" -n 1' sfeed_update || { echo "sfeed_update changed upstream, fix the xargs patch"; exit 1; }
sed -i 's/xargs -x -0 -P "${maxjobs}" -n 1/xargs -x -0 -n 1/' sfeed_update

CC="$PROJ/scripts/maemo-gcc"
# - -D_GNU_SOURCE: glibc 2.5 does not know _XOPEN_SOURCE=700 (set by the upstream Makefile) and then does not define ssize_t in <stdio.h>; sys/types.h is included first.
# - sfeed_curses uses the plain libcurses (device: libncurses5).
make -j"$(nproc)" CC="$CC" AR=arm-linux-gnueabi-ar RANLIB=arm-linux-gnueabi-ranlib \
    CFLAGS="-Os -D_GNU_SOURCE -include sys/types.h -include $PROJ/scripts/maemo-compat.h" \
    > "$OUT/make.log" 2>&1 || { grep -E 'error|Error' "$OUT/make.log" | head -20; exit 1; }
make install DESTDIR="$OUT/root" PREFIX=/opt/sfeed MANPREFIX=/opt/sfeed/share/man \
    >> "$OUT/make.log" 2>&1 || { tail -20 "$OUT/make.log"; exit 1; }
for b in "$OUT"/root/opt/sfeed/bin/sfeed*; do
    if file "$b" | grep -q ELF; then arm-linux-gnueabi-strip "$b"; fi
done

echo "== Check"
ls -l "$OUT/root/opt/sfeed/bin"
