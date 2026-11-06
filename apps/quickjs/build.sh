#!/bin/bash
# Cross-build QuickJS (Fabrice Bellard) for Maemo 5 (armel, glibc 2.5). Run INSIDE the Workshop:  make -C apps/quickjs build
# Why: yt-dlp needs an external JavaScript runtime to solve the YouTube player challenges (Deno, Node, Bun or QuickJS);
# only QuickJS is small enough (a few hundred kB) and plain C, so it builds for the N900. See DOC/youtube-n900.md.
# Output: /project/build/out/quickjs-$VERSION/qjs   (stripped binary)
set -euo pipefail

VERSION="${VERSION:-2026-06-04}"
PROJ=/project
SR="$PROJ/sysroot"
DL="$PROJ/build/downloads"
SRCDIR="$PROJ/build/src"
OUT="$PROJ/build/out/quickjs-$VERSION"

[ -d "$SR/usr/include" ] || { echo "Missing sysroot, run: make sysroot"; exit 1; }
mkdir -p "$DL" "$SRCDIR"
f="quickjs-$VERSION.tar.xz"
[ -s "$DL/$f" ] || curl -fL --retry 3 -o "$DL/$f" "https://bellard.org/quickjs/$f"
echo "sha256 $(sha256sum "$DL/$f" | cut -d' ' -f1)  $f"
rm -rf "$SRCDIR/quickjs-$VERSION" "$OUT"
mkdir -p "$OUT"
tar -C "$SRCDIR" -xJf "$DL/$f"
cd "$SRCDIR/quickjs-$VERSION"
# CROSS_PREFIX makes the Makefile build a host qjsc (HOST_CC) first, which compiles repl.js and the standard library into C.
# CC/AR: our wrapper (sysroot with glibc 2.5). CFLAGS from the environment is extended by the Makefile (CFLAGS+=...).
# -latomic is not needed on ARMv7. Only qjs is built (the test suite program is not needed).
export CFLAGS="-include $PROJ/scripts/maemo-compat.h"
make qjs CROSS_PREFIX=arm-linux-gnueabi- CC="$PROJ/scripts/maemo-gcc" AR=arm-linux-gnueabi-ar HOST_CC=gcc \
     LDFLAGS="-Wl,--no-as-needed" LIBS="-lm -ldl -lpthread -lrt" -j"$(nproc)" > "$OUT/make.log" 2>&1 \
    || { grep -E "error|Error|undefined" "$OUT/make.log" | head -20; tail -5 "$OUT/make.log"; exit 1; }
arm-linux-gnueabi-strip -o "$OUT/qjs" qjs
echo "== Check"
file "$OUT/qjs"
ls -l "$OUT/qjs"
cp LICENSE "$OUT/LICENSE"
