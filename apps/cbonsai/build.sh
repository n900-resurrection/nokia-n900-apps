#!/bin/bash
# Cross-build cbonsai for Maemo 5 (armel, glibc 2.5). Run INSIDE the Workshop:
#   workshop exec n900 -- bash -c 'VERSION=1.4.2 /project/apps/cbonsai/build.sh'   (or: make -C apps/cbonsai build)
# Output: /project/build/out/cbonsai-$VERSION/cbonsai (stripped binary)
#
# cbonsai draws wide characters (cchar_t, wchar_t), so it needs ncursesw. The device only has the
# non-wide libncurses5, therefore ncursesw and panelw are linked STATICALLY (same as WordGrinder).
set -euo pipefail

VERSION="${VERSION:-1.4.2}"
PROJ=/project
SR="$PROJ/sysroot"
SRC="$PROJ/build/upstream/cbonsai"
OUT="$PROJ/build/out/cbonsai-$VERSION"

[ -d "$SR/usr/include" ] || { echo "Missing sysroot, run: make sysroot"; exit 1; }

# 1. Sources. The project moved from GitHub to GitLab; tag v$VERSION.
if [ ! -d "$SRC/.git" ]; then
    mkdir -p "$(dirname "$SRC")"
    git clone -q https://gitlab.com/jallbrit/cbonsai.git "$SRC"
fi
git -C "$SRC" fetch -q --tags
git -C "$SRC" checkout -q -f "v$VERSION"

# 2. Build. One source file; the upstream Makefile only gets flags from pkg-config, which the
#    sysroot lacks. The wide-character header lives in usr/include/ncursesw. The man page is
#    built with scdoc when that is installed (optional).
rm -rf "$OUT"; mkdir -p "$OUT"
"$PROJ/scripts/maemo-gcc" -Os -Wall -std=gnu99 -D_XOPEN_SOURCE_EXTENDED -o "$OUT/cbonsai.unstripped" "$SRC/cbonsai.c" \
    -I"$SR/usr/include/ncursesw" \
    -Wl,-Bstatic -lpanelw -lncursesw -Wl,-Bdynamic
arm-linux-gnueabi-strip -o "$OUT/cbonsai" "$OUT/cbonsai.unstripped"
rm "$OUT/cbonsai.unstripped"
if command -v scdoc >/dev/null; then scdoc < "$SRC/cbonsai.scd" > "$OUT/cbonsai.6"; fi

echo "== Check"
file "$OUT/cbonsai" | cut -c1-140
arm-linux-gnueabi-readelf -d "$OUT/cbonsai" | grep NEEDED
echo -n "Highest glibc symbol: "
arm-linux-gnueabi-objdump -T "$OUT/cbonsai" | grep -oE 'GLIBC_[0-9.]+' | sort -uV | tail -1
ls -l "$OUT/cbonsai"
