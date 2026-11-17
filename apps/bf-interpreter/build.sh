#!/bin/bash
# Cross-build the Brainfuck interpreter for Maemo 5 (armel, glibc 2.5). Run INSIDE the Workshop:
#   workshop exec n900 -- bash -c '/project/apps/bf-interpreter/build.sh'   (or: make -C apps/bf-interpreter build)
# Output: /project/build/out/bf-interpreter-$VERSION/bf (stripped binary)
#
# The interpreter is one C file that needs only libc. The sources are pinned to a commit of github.com/elPytel/BF_interpreter
# (the project has no releases); raise COMMIT when the interpreter changes, and the REV of the package with it.
set -euo pipefail

VERSION="${VERSION:-0.1}"
COMMIT="${COMMIT:-c9ad0e8}"
PROJ=/project
SRC="$PROJ/build/upstream/bf-interpreter"
OUT="$PROJ/build/out/bf-interpreter-$VERSION"

[ -d "$PROJ/sysroot/usr/include" ] || { echo "Missing sysroot, run: make sysroot"; exit 1; }

# 1. Sources
if [ ! -d "$SRC/.git" ]; then
    mkdir -p "$(dirname "$SRC")"
    git clone -q https://github.com/elPytel/BF_interpreter.git "$SRC"
fi
git -C "$SRC" fetch -q origin
git -C "$SRC" checkout -q -f "$COMMIT"

# 2. Build: the upstream Makefile wants clang and -lm; the code needs neither
rm -rf "$OUT"; mkdir -p "$OUT"
"$PROJ/scripts/maemo-gcc" -Os -Wall -o "$OUT/bf.unstripped" "$SRC/bf.c"
arm-linux-gnueabi-strip -o "$OUT/bf" "$OUT/bf.unstripped"
rm "$OUT/bf.unstripped"

echo "== Check"
file "$OUT/bf" | cut -c1-140
arm-linux-gnueabi-readelf -d "$OUT/bf" | grep NEEDED
echo -n "Highest glibc symbol: "
arm-linux-gnueabi-objdump -T "$OUT/bf" | grep -oE 'GLIBC_[0-9.]+' | sort -uV | tail -1
ls -l "$OUT/bf"
