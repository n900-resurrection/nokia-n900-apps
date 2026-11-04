#!/bin/bash
# Package the built curl as a .deb ("curl") for Maemo 5. Run INSIDE the Workshop after build.sh:
#   workshop exec n900 -- bash -c 'CURL_VERSION=8.23.0 REV=1maemo1 /project/apps/curl/package.sh'
#   (or on the host: make -C apps/curl deb)
# Output: /project/build/deb/curl_<CURL_VERSION>-<REV>_armel.deb
#
# Status: the package builds and can be inspected. Installation on a device is not verified yet.
set -euo pipefail

APP=curl
CURL_VERSION="${CURL_VERSION:-8.23.0}"
MBEDTLS_VERSION="${MBEDTLS_VERSION:-3.6.7}"
REV="${REV:-1maemo1}"
MAINT="${MAINTAINER:-elPytel}"
PROJ=/project
OUT="$PROJ/build/out/curl-$CURL_VERSION"
SRC="$PROJ/build/src/curl-$CURL_VERSION"
MBEDSRC="$PROJ/build/src/mbedtls-$MBEDTLS_VERSION"
STAGE="$PROJ/build/deb/stage-$APP"
DEB="$PROJ/build/deb/${APP}_${CURL_VERSION}-${REV}_armel.deb"

[ -x "$OUT/curl" ] && [ -s "$OUT/cacert.pem" ] || { echo "Missing build output in $OUT, run build.sh first (make build)"; exit 1; }

rm -rf "$STAGE"
mkdir -p "$STAGE/DEBIAN" \
         "$STAGE/opt/$APP/bin" \
         "$STAGE/opt/$APP/etc/ssl" \
         "$STAGE/opt/$APP/share/doc/$APP" \
         "$STAGE/usr/bin"

install -m 755 "$OUT/curl" "$STAGE/opt/$APP/bin/curl"
# Default CA store, compiled into the binary as /opt/curl/etc/ssl/cacert.pem.
install -m 644 "$OUT/cacert.pem" "$STAGE/opt/$APP/etc/ssl/cacert.pem"
ln -s "../../opt/$APP/bin/curl" "$STAGE/usr/bin/curl"

# Licenses: curl (curl license), mbedTLS (Apache-2.0 or GPL-2.0-or-later), zlib (zlib license).
install -m 644 "$SRC/COPYING" "$STAGE/opt/$APP/share/doc/$APP/COPYING.curl"
[ -f "$MBEDSRC/LICENSE" ] && install -m 644 "$MBEDSRC/LICENSE" "$STAGE/opt/$APP/share/doc/$APP/LICENSE.mbedtls"
cat > "$STAGE/opt/$APP/share/doc/$APP/README.Maemo" <<EOF
curl $CURL_VERSION built for Maemo 5 (armel, glibc 2.5). Upstream: https://curl.se/
Linked statically with mbedTLS $MBEDTLS_VERSION (TLS 1.2/1.3) and a private zlib, so it does not use the
old OpenSSL 0.9.8 of the device (TLS 1.0 only), which cannot talk to modern HTTPS servers.

CA bundle: /opt/curl/etc/ssl/cacert.pem (Mozilla roots, from https://curl.se/ca/cacert.pem, snapshot
of the build date). It is NOT updated automatically; to refresh it:
  curl -o /opt/curl/etc/ssl/cacert.pem https://curl.se/ca/cacert.pem

Randomness: mbedTLS reads /dev/urandom (instead of the default /dev/random, which blocks on this
kernel because it has no getrandom()); see apps/curl/mbedtls-urandom.h in the build repository.

Needs the glibc symbol GLIBC_2.7 (eventfd), which the eglibc 2.5.1-1eglibc27 of Maemo 5 provides.
EOF

SIZE_KB=$(du -sk "$STAGE" | cut -f1)
cat > "$STAGE/DEBIAN/control" <<EOF
Package: $APP
Version: $CURL_VERSION-$REV
Architecture: armel
Section: user/network
Priority: optional
Installed-Size: $SIZE_KB
Depends: libc6 (>= 2.5.1-1eglibc27)
Maintainer: $MAINT
XB-Maemo-Display-Name: curl
Description: Command line tool for transferring data with URLs (TLS 1.3)
 curl $CURL_VERSION with mbedTLS $MBEDTLS_VERSION, built for Maemo 5. Supports HTTPS with TLS 1.2/1.3,
 so it works with servers that the system OpenSSL 0.9.8 of the device cannot talk to.
 Installed in /opt/curl, with a link /usr/bin/curl. Upstream: https://curl.se/
EOF

# Uniform permissions (the container umask gives group-write): directories 755, files 644,
# executables stay 755.
chmod -R u+rwX,go+rX,go-w "$STAGE"

mkdir -p "$(dirname "$DEB")"
# gzip: the old dpkg on Maemo 5 (1.14) does not know xz. --root-owner-group: files belong to root:root.
dpkg-deb --root-owner-group -Zgzip --build "$STAGE" "$DEB"

echo "== Package"
dpkg-deb -I "$DEB"
dpkg-deb -c "$DEB"
ls -l "$DEB"
