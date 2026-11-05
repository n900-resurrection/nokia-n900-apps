#!/bin/bash
# Cross-build msmtp (SMTP client for sending mail, used by Mutt as "sendmail") with TLS 1.3 (static OpenSSL 3).
# Run INSIDE the Workshop:  workshop exec n900 -- bash -c 'VERSION=1.8.34 /project/apps/msmtp/build.sh'
#   (or: make -C apps/msmtp build). Needs: make -C apps/openssl build
# Output: /project/build/out/msmtp-$VERSION/msmtp   (stripped binary)
#
# Why: Mutt without Cyrus SASL cannot log in to an SMTP server (smtp_url works only for servers without
# authentication). msmtp does the login and TLS itself, Mutt just pipes the message to it.
set -euo pipefail

VERSION="${VERSION:-1.8.34}"
OPENSSL_VERSION="${OPENSSL_VERSION:-3.5.9}"
PROJ=/project
SR="$PROJ/sysroot"
DL="$PROJ/build/downloads"
SRCDIR="$PROJ/build/src"
OUT="$PROJ/build/out/msmtp-$VERSION"
OBJ="$PROJ/build/obj/msmtp-$VERSION"
SSL="$PROJ/build/deps/openssl-$OPENSSL_VERSION"

[ -d "$SR/usr/include" ] || { echo "Missing sysroot, run: make sysroot"; exit 1; }
[ -f "$SSL/lib/libssl.a" ] || { echo "Missing OpenSSL, run: make -C apps/openssl build"; exit 1; }
mkdir -p "$DL" "$SRCDIR"
f="msmtp-$VERSION.tar.xz"
[ -s "$DL/$f" ] || curl -fL --retry 3 -o "$DL/$f" "https://marlam.de/msmtp/releases/$f"
echo "sha256 $(sha256sum "$DL/$f" | cut -d' ' -f1)  $f"
rm -rf "$SRCDIR/msmtp-$VERSION" "$OBJ" "$OUT"
tar -C "$SRCDIR" -xJf "$DL/$f"
mkdir -p "$OBJ" "$OUT/root"
cd "$OBJ"

export MAEMO_DEPS="$SSL"
# - libssl_CFLAGS/libssl_LIBS replace pkg-config (no .pc files for the cross-built OpenSSL).
"$SRCDIR/msmtp-$VERSION/configure" \
    --host=arm-linux-gnueabi --build="$(gcc -dumpmachine)" \
    --prefix=/opt/msmtp --sysconfdir=/opt/msmtp/etc \
    --with-tls=openssl --without-libidn --without-libgsasl --without-libsecret --without-macosx-keyring \
    --disable-nls --without-msmtpd \
    CC="$PROJ/scripts/maemo-gcc" \
    CFLAGS="-Os -include $PROJ/scripts/maemo-compat.h -DO_BINARY=0 -DO_TEXT=0" \
    LIBS="-ldl -lpthread -lrt" \
    libssl_CFLAGS="-I$SSL/include" libssl_LIBS="$SSL/lib/libssl.a $SSL/lib/libcrypto.a -ldl -lpthread" \
    > "$OUT/configure.log" 2>&1 || { tail -30 "$OUT/configure.log"; exit 1; }
make -j"$(nproc)" -C src > "$OUT/make.log" 2>&1 \
    || { grep -E 'error|Error' "$OUT/make.log" | head -20; exit 1; }
arm-linux-gnueabi-strip -o "$OUT/msmtp" src/msmtp

echo "== Check"
file "$OUT/msmtp" | cut -c1-140
ls -l "$OUT/msmtp"
