#!/bin/bash
# Cross-build libsmb2 (SMB2/SMB3 client library, LGPL-2.1, own NTLMSSP and AES, no Kerberos) as a static library.
# Run INSIDE the Workshop. Output prefix: /project/build/deps/libsmb2-$LIBVERSION
set -euo pipefail
LIBVERSION="${LIBVERSION:-6.3}"
PROJ=/project
DL="$PROJ/build/downloads"; SRCDIR="$PROJ/build/src"; OBJ="$PROJ/build/obj/libsmb2-$LIBVERSION"
PREFIX="$PROJ/build/deps/libsmb2-$LIBVERSION"
f="libsmb2-$LIBVERSION.tar.gz"
mkdir -p "$DL" "$SRCDIR"
[ -s "$DL/$f" ] || curl -fL --retry 3 -o "$DL/$f" "https://github.com/sahlberg/libsmb2/archive/refs/tags/libsmb2-$LIBVERSION.tar.gz"
echo "sha256 $(sha256sum "$DL/$f" | cut -d' ' -f1)  $f"
rm -rf "$SRCDIR/libsmb2-libsmb2-$LIBVERSION" "$OBJ" "$PREFIX"
tar -C "$SRCDIR" -xzf "$DL/$f"
mkdir -p "$OBJ"
cd "$SRCDIR/libsmb2-libsmb2-$LIBVERSION"
sh ./bootstrap > "$OBJ/bootstrap.log" 2>&1 || { tail -20 "$OBJ/bootstrap.log"; exit 1; }
cd "$OBJ"
"$SRCDIR/libsmb2-libsmb2-$LIBVERSION/configure" --host=arm-linux-gnueabi --build="$(gcc -dumpmachine)" --prefix="$PREFIX" \
    --disable-shared --enable-static --without-libkrb5 --disable-examples --disable-werror \
    CC="$PROJ/scripts/maemo-gcc" CFLAGS="-Os -include $PROJ/scripts/maemo-compat.h -include $PROJ/apps/smb/endian-compat.h" > configure.log 2>&1 || { tail -30 configure.log; exit 1; }
make -j"$(nproc)" > make.log 2>&1 || { grep -E 'error' make.log | head -20; tail -5 make.log; exit 1; }
make install > install.log 2>&1
ls -l "$PREFIX/lib"
