#!/bin/bash
# Cross-build the `smb` client (smb.c + static libsmb2) for Maemo 5 (armel, glibc 2.5). Run INSIDE the Workshop: make -C apps/smb build
# Output: /project/build/out/smb-$VERSION/smb   (stripped binary)
set -euo pipefail
VERSION="${VERSION:-0.1}"; export LIBVERSION="${LIBVERSION:-6.3}"
PROJ=/project
PREFIX="$PROJ/build/deps/libsmb2-$LIBVERSION"
OUT="$PROJ/build/out/smb-$VERSION"
[ -f "$PREFIX/lib/libsmb2.a" ] || "$PROJ/apps/smb/build-lib.sh"
rm -rf "$OUT"; mkdir -p "$OUT"
"$PROJ/scripts/maemo-gcc" -Os -Wall -include "$PROJ/scripts/maemo-compat.h" -include "$PROJ/apps/smb/endian-compat.h" \
    -I"$PREFIX/include" -I"$PREFIX/include/smb2" -o "$OUT/smb.unstripped" "$PROJ/apps/smb/smb.c" "$PREFIX/lib/libsmb2.a"
arm-linux-gnueabi-strip -o "$OUT/smb" "$OUT/smb.unstripped"; rm "$OUT/smb.unstripped"
echo "== Check"
file "$OUT/smb" | cut -c1-140
ls -l "$OUT/smb"
arm-linux-gnueabi-objdump -T "$OUT/smb" | grep -o 'GLIBC_[0-9.]*' | sort -uV | tail -1
