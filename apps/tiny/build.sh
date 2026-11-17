#!/bin/bash
# Cross-build TINY (full-screen interface on ncurses) for Maemo 5 (armel, glibc 2.5). Run INSIDE the Workshop (make -C apps/tiny build).
# Output: /project/build/out/tiny-$VERSION/tiny-bin (stripped, ncurses linked statically), TINY.BIN (the network)
#
# The sources are the fork github.com/n900-resurrection/Tiny-2.1, branch n900, pinned to a commit (COMMIT); raise it, and REV of the package, when the port changes.
# TINY_SRC=/path/to/a/checkout builds from a local working copy instead (for development).
set -euo pipefail

VERSION="${VERSION:-2.1}"
COMMIT="${COMMIT:-6b83764}"
PROJ=/project
SRC="$PROJ/build/upstream/tiny"
OUT="$PROJ/build/out/tiny-$VERSION"

[ -d "$PROJ/sysroot/usr/include" ] || { echo "Missing sysroot, run: make sysroot"; exit 1; }
if [ -n "${TINY_SRC:-}" ]; then
    SRC="$TINY_SRC"
else
    if [ ! -d "$SRC/.git" ]; then
        mkdir -p "$(dirname "$SRC")"
        git clone -q https://github.com/n900-resurrection/Tiny-2.1.git "$SRC"
    fi
    git -C "$SRC" fetch -q origin n900
    git -C "$SRC" checkout -q -f "$COMMIT"
fi

rm -rf "$OUT"; mkdir -p "$OUT"
# ncurses is linked statically: the phone has libncurses5 but not the wide-character libncursesw
make -C "$SRC" clean >/dev/null
make -C "$SRC" tiny CC="$PROJ/scripts/maemo-gcc" CFLAGS="-Os" NCURSES_LIBS="-Wl,-Bstatic -lncursesw -Wl,-Bdynamic" \
    MODEL_PATH=/opt/tiny/share/tiny/TINY.BIN 2>&1 | grep -v fgnu89
arm-linux-gnueabi-strip -o "$OUT/tiny-bin" "$SRC/tiny"
install -m 644 "$SRC/dos/TINY.BIN" "$OUT/TINY.BIN"
make -C "$SRC" clean >/dev/null

echo "== Check"
file "$OUT/tiny-bin" | cut -c1-140
arm-linux-gnueabi-readelf -d "$OUT/tiny-bin" | grep NEEDED
echo -n "Highest glibc symbol: "
arm-linux-gnueabi-objdump -T "$OUT/tiny-bin" | grep -oE 'GLIBC_[0-9.]+' | sort -uV | tail -1
ls -l "$OUT"
