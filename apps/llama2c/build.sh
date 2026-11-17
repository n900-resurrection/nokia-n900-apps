#!/bin/bash
# Cross-build llama2.c (run.c, runq.c) for Maemo 5 (armel, glibc 2.5). Run INSIDE the Workshop (make -C apps/llama2c build).
# Output: /project/build/out/llama2c-$VERSION/{llama2c,llama2c-q8,tokenizer.bin,stories260K.bin,tok512.bin}
#
# The sources are pinned to a commit of github.com/karpathy/llama2.c (it has no releases). The small demo model stories260K (1 MB) and its tokenizer come from
# huggingface.co/karpathy/tinyllamas; the bigger stories15M (61 MB) is not packaged, the launcher downloads it.
set -euo pipefail

VERSION="${VERSION:-0.0.20240529}"
COMMIT="${COMMIT:-350e04f}"
PROJ=/project
SRC="$PROJ/build/upstream/llama2c"
DL="$PROJ/build/downloads"
OUT="$PROJ/build/out/llama2c-$VERSION"

[ -d "$PROJ/sysroot/usr/include" ] || { echo "Missing sysroot, run: make sysroot"; exit 1; }
if [ ! -d "$SRC/.git" ]; then
    mkdir -p "$(dirname "$SRC")"
    git clone -q https://github.com/karpathy/llama2.c.git "$SRC"
fi
git -C "$SRC" fetch -q origin
git -C "$SRC" checkout -q -f "$COMMIT"

rm -rf "$OUT"; mkdir -p "$OUT" "$DL"
# the compiler of the kit already targets ARMv7 with NEON; -lrt for clock_gettime of the old glibc
for p in "run:llama2c" "runq:llama2c-q8"; do
    src=${p%%:*}; dst=${p##*:}
    "$PROJ/scripts/maemo-gcc" -O3 -ffast-math -Wall -o "$OUT/$dst.unstripped" "$SRC/$src.c" -lm -lrt 2>&1 | grep -E 'error' || true
    arm-linux-gnueabi-strip -o "$OUT/$dst" "$OUT/$dst.unstripped"; rm "$OUT/$dst.unstripped"
done
install -m 644 "$SRC/tokenizer.bin" "$OUT/tokenizer.bin"
fetch() { # file url sha256
    [ -s "$DL/$1" ] || curl -fL --retry 3 -o "$DL/$1" "$2"
    echo "$3  $DL/$1" | sha256sum -c - > /dev/null || { echo "sha256 of $1 differs"; exit 1; }
    install -m 644 "$DL/$1" "$OUT/$1"
}
HF=https://huggingface.co/karpathy/tinyllamas/resolve/main/stories260K
fetch stories260K.bin "$HF/stories260K.bin" b0a507e7ad0f626624f17112325e66691f9076d622e1d3274d103d00299f2696
fetch tok512.bin "$HF/tok512.bin" 037cb335abb25d1fa9e8ecae30ed2a3a8ace9302862ebcdc05d51a6bbb10c312

echo "== Check"
file "$OUT/llama2c" | cut -c1-120
arm-linux-gnueabi-readelf -d "$OUT/llama2c" | grep NEEDED
ls -l "$OUT"
