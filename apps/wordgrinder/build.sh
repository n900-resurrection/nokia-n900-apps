#!/bin/bash
# Cross-build WordGrinder pro Maemo 5 (armel, glibc 2.5). Spouští se UVNITŘ Workshopu:
#   workshop exec n900 -- /project/apps/wordgrinder/build.sh      (nebo: make wordgrinder)
# Výstup: /project/build/out/wordgrinder-$VERSION/opt/wordgrinder/... a stripnutá binárka
#         /project/build/out/wordgrinder-$VERSION/wordgrinder
#
# Ověřeno 2026-11-04 pro VERSION=0.8 (Lua 5.1 přibalená, ncursesw linkováno staticky).
set -euo pipefail

VERSION="${VERSION:-0.8}"
PROJ=/project
SR="$PROJ/sysroot"
SRC="$PROJ/build/upstream/wordgrinder"
OUT="$PROJ/build/out/wordgrinder-$VERSION"
OBJ="$PROJ/build/obj/wordgrinder-$VERSION"

[ -d "$SR/usr/include" ] || { echo "Chybí sysroot, spusť: make sysroot"; exit 1; }

# 1. Zdrojáky (upstream, mimo verzování)
if [ ! -d "$SRC/.git" ]; then
    mkdir -p "$(dirname "$SRC")"
    git clone -q https://github.com/davidgiven/wordgrinder.git "$SRC"
fi
git -C "$SRC" checkout -q -f "$VERSION"

# 2. Hostitelská Lua. Makefile ji jinak staví cílovým $(CC) a pak by ji nešlo spustit.
mkdir -p "$PROJ/build/host"
gcc -O -o "$PROJ/build/host/lua" \
    "$SRC"/src/c/emu/lua-5.1.5/*.c "$SRC"/src/c/emu/tmpnam.c -lm -DLUA_USE_EMU_TMPNAM

# 3. Cílový překlad.
#  - ncursesw: širokoznaková hlavička je v usr/include/ncursesw, knihovna se linkuje STATICKY,
#    protože ji telefon nemá (má jen libc, libm, libz).
#  - WANT_STRIPPED_BINARIES=no: Makefile volá hostitelský strip, strip děláme sami níže.
rm -rf "$OBJ" "$OUT"
make -C "$SRC" clean >/dev/null 2>&1 || true
make -C "$SRC" install-notests \
    LUA_INTERPRETER="$PROJ/build/host/lua" OBJDIR="$OBJ" \
    CC="$PROJ/scripts/maemo-gcc" NINJA=ninja VERSION="$VERSION" \
    CURSES_PACKAGE="--cflags={-I$SR/usr/include/ncursesw -I$SR/usr/include} --libs={-L$SR/usr/lib -Wl,-Bstatic -lncursesw -Wl,-Bdynamic}" \
    WANT_STRIPPED_BINARIES=no \
    PREFIX=/opt/wordgrinder DESTDIR="$OUT"

BIN="$OUT/opt/wordgrinder/bin/wordgrinder"
arm-linux-gnueabi-strip -o "$OUT/wordgrinder" "$BIN"

echo "== Kontrola"
file "$OUT/wordgrinder" | cut -c1-140
arm-linux-gnueabi-readelf -d "$OUT/wordgrinder" | grep NEEDED
echo -n "Nejvyšší symbol glibc: "
arm-linux-gnueabi-objdump -T "$OUT/wordgrinder" | grep -oE 'GLIBC_[0-9.]+' | sort -uV | tail -1
ls -l "$OUT/wordgrinder"
