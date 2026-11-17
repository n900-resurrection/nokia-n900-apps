#!/bin/bash
# Cross-build mandoc (man, apropos, whatis, makewhatis) for Maemo 5 (armel, glibc 2.5). Run INSIDE the Workshop (make -C apps/mandoc build).
# Output: /project/build/out/mandoc-$VERSION/root/opt/mandoc/{bin,share}
#
# mandoc is one C program (BSD-style ISC licence) that formats man pages itself, without groff/nroff, which the phone lacks.
# zlib is linked statically (the pages of our packages are .gz). mandoc's configure runs its feature tests as programs: under qemu-user (QEMU_LD_PREFIX).
set -euo pipefail

VERSION="${VERSION:-1.14.6}"
SHA256="8bf0d570f01e70a6e124884088870cbed7537f36328d512909eb10cd53179d9c"
PROJ=/project
SR="$PROJ/sysroot"
DL="$PROJ/build/downloads"
SRCDIR="$PROJ/build/src"
OUT="$PROJ/build/out/mandoc-$VERSION"

[ -d "$SR/usr/include" ] || { echo "Missing sysroot, run: make sysroot"; exit 1; }
mkdir -p "$DL" "$SRCDIR"
f="mandoc-$VERSION.tar.gz"
[ -s "$DL/$f" ] || curl -fL --retry 3 -o "$DL/$f" "https://mandoc.bsd.lv/snapshots/$f"
echo "$SHA256  $DL/$f" | sha256sum -c - >/dev/null || { echo "sha256 of $f differs"; exit 1; }
rm -rf "$SRCDIR/mandoc-$VERSION" "$OUT"
tar -C "$SRCDIR" -xzf "$DL/$f"
mkdir -p "$OUT/root"
cd "$SRCDIR/mandoc-$VERSION"

cat > configure.local <<EOT
PREFIX=/opt/mandoc
BINDIR=/opt/mandoc/bin
SBINDIR=/opt/mandoc/bin
MANDIR=/opt/mandoc/share/man
MISCDIR=/opt/mandoc/share
BIN_FROM_SBIN=
CC="$PROJ/scripts/maemo-gcc"
AR=arm-linux-gnueabi-ar
CFLAGS="-Os -D_GNU_SOURCE -include $PROJ/scripts/maemo-compat.h"
LDFLAGS="-static"
LDADD="-lz"
UTF8_LOCALE=
HAVE_LESS_T=0          # the BusyBox less of the phone has no -T (configure tested the less of the build host)
MANPATH_DEFAULT=/usr/share/man:/opt/mandoc/share/man
MANPATH_BASE=/usr/share/man
OSNAME=Linux
INSTALL_LIBMANDOC=0
BUILD_DB=1
HAVE_MANPATH=0
EOT
export QEMU_LD_PREFIX="$SR"       # the feature tests of configure are ARM programs: they run under qemu-user (binfmt) with the libraries of the sysroot
./configure > "$OUT/configure.log" 2>&1 || { tail -30 "$OUT/configure.log"; exit 1; }
make -j"$(nproc)" > "$OUT/make.log" 2>&1 || { grep -E 'error|Error' "$OUT/make.log" | head -20; tail -15 "$OUT/make.log"; exit 1; }
make install DESTDIR="$OUT/root" > "$OUT/install.log" 2>&1 || { tail -20 "$OUT/install.log"; exit 1; }
arm-linux-gnueabi-strip "$OUT/root/opt/mandoc/bin/mandoc" "$OUT/root/opt/mandoc/bin/makewhatis" 2>/dev/null || true

echo "== Check"
cd "$OUT/root/opt/mandoc"; find . -type f -o -type l | sort | head -30
BIN=bin/mandoc
file "$BIN" | cut -c1-140
arm-linux-gnueabi-readelf -d "$BIN" 2>&1 | grep NEEDED || echo "(static: no NEEDED)"
echo "Kernel ABI: $(file "$BIN" | grep -o 'for GNU/Linux [0-9.]*')"   # static: no glibc symbol versions
ls -l bin
