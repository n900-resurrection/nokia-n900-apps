#!/bin/bash
# Cross-build Stockfish 11 (the last version before NNUE: classical evaluation, no 40 MB network file) for the N900. Run INSIDE the Workshop
# (make -C apps/stockfish build). Static musl binary built with the musl cross g++ (needs: make -C apps/gurk build once, it fetches the toolchain).
# Output: /project/build/out/stockfish-$VERSION/stockfish
set -euo pipefail
ROOT=/project
VERSION="${VERSION:-11}"
TAG="sf_$VERSION"
T="$ROOT/build/rust/musl-cross/bin/arm-linux-musleabi"
[ -x "$T-g++" ] || { echo "Missing $T-g++, run: make -C apps/gurk build"; exit 1; }
DL="$ROOT/build/downloads"; mkdir -p "$DL"
SRCTGZ="$DL/stockfish-$TAG.tar.gz"
[ -s "$SRCTGZ" ] || curl -fL --retry 3 -o "$SRCTGZ" "https://github.com/official-stockfish/Stockfish/archive/refs/tags/$TAG.tar.gz"
echo "sha256 $(sha256sum "$SRCTGZ" | cut -d' ' -f1)"
OUT="$ROOT/build/out/stockfish-$VERSION"
W="$ROOT/build/stockfish-src"
rm -rf "$W" "$OUT"; mkdir -p "$W" "$OUT"
tar -C "$W" -xzf "$SRCTGZ" --strip-components=1
cd "$W/src"
make -j"$(nproc)" build ARCH=armv7 COMP=gcc CXX="$T-g++" \
     EXTRACXXFLAGS="-mcpu=cortex-a8 -mfpu=neon -mfloat-abi=softfp" EXTRALDFLAGS="-static" 2>&1 | tail -25
arm-linux-gnueabi-strip -o "$OUT/stockfish" stockfish
cp ../Copying.txt ../AUTHORS "$OUT/" 2>/dev/null || true
echo "== Check"
file "$OUT/stockfish" | cut -c1-150
ls -l "$OUT/stockfish"
echo "== qemu-user"
qemu-arm "$OUT/stockfish" <<< $'uci\nquit' | sed -n 1,3p
