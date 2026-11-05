#!/bin/bash
# Cross-build Mutt 2.x (terminal e-mail client) with TLS 1.2/1.3 (static OpenSSL 3) for Maemo 5.
# Run INSIDE the Workshop:  workshop exec n900 -- bash -c 'VERSION=2.4.3 /project/apps/mutt/build.sh'
#   (or: make -C apps/mutt build). Needs: make -C apps/openssl build
# Output: /project/build/out/mutt-$VERSION/{mutt,root/opt/mutt/...}
#
# ncursesw (needed for UTF-8) is linked statically, see below. IMAP, POP3 and SMTP are built in,
# no SASL (AUTH PLAIN/LOGIN over TLS is enough for Centrum), no header cache, no NLS.
set -euo pipefail

VERSION="${VERSION:-2.4.3}"
OPENSSL_VERSION="${OPENSSL_VERSION:-3.5.9}"
PROJ=/project
SR="$PROJ/sysroot"
DL="$PROJ/build/downloads"
SRCDIR="$PROJ/build/src"
OUT="$PROJ/build/out/mutt-$VERSION"
OBJ="$PROJ/build/obj/mutt-$VERSION"
SSL="$PROJ/build/deps/openssl-$OPENSSL_VERSION"

[ -d "$SR/usr/include" ] || { echo "Missing sysroot, run: make sysroot"; exit 1; }
[ -f "$SSL/lib/libssl.a" ] || { echo "Missing OpenSSL, run: make -C apps/openssl build"; exit 1; }
mkdir -p "$DL" "$SRCDIR"
f="mutt-$VERSION.tar.gz"
[ -s "$DL/$f" ] || curl -fL --retry 3 -o "$DL/$f" "http://ftp.mutt.org/pub/mutt/$f"
echo "sha256 $(sha256sum "$DL/$f" | cut -d' ' -f1)  $f"
rm -rf "$SRCDIR/mutt-$VERSION" "$OBJ" "$OUT"
tar -C "$SRCDIR" -xzf "$DL/$f"
mkdir -p "$OBJ" "$OUT/root"
cd "$OBJ"

# Wide-character ncurses is linked STATICALLY: the device only has libncurses5 (no libncursesw). A directory
# that contains only the static archive makes -lncursesw pick it instead of the shared library.
NCW="$PROJ/build/deps/ncursesw-static"
mkdir -p "$NCW/lib"
cp "$SR/usr/lib/libncursesw.a" "$NCW/lib/"
export MAEMO_DEPS="$SSL:$NCW"
# Answers for tests that cannot run when cross-compiling (glibc on Linux):
export mutt_cv_c99_snprintf=yes mutt_cv_c99_vsnprintf=yes mutt_cv_fchmod=yes \
       ac_cv_c_bigendian=no mutt_cv_iconv_good=yes mutt_cv_iconv_nontrans=no \
       mutt_cv_bcopy=no mutt_cv_regex=no ac_cv_func_setpgrp_void=yes
"$SRCDIR/mutt-$VERSION/configure" \
    --host=arm-linux-gnueabi --build="$(gcc -dumpmachine)" \
    --prefix=/opt/mutt --sysconfdir=/opt/mutt/etc \
    --with-ssl="$SSL" --enable-imap --enable-pop --enable-smtp \
    --with-curses --disable-nls --disable-gpgme --disable-hcache --disable-doc \
    --with-homespool=no --disable-flock --enable-fcntl \
    --with-mailpath=/var/mail \
    CC="$PROJ/scripts/maemo-gcc" \
    CFLAGS="-Os -include $PROJ/scripts/maemo-compat.h" \
    LIBS="-ldl -lpthread" \
    > "$OUT/configure.log" 2>&1 || { tail -30 "$OUT/configure.log"; exit 1; }
make -j"$(nproc)" > "$OUT/make.log" 2>&1 || { grep -E 'error|Error' "$OUT/make.log" | head -20; exit 1; }
arm-linux-gnueabi-strip -o "$OUT/mutt" mutt

echo "== Check"
file "$OUT/mutt" | cut -c1-140
ls -l "$OUT/mutt"
