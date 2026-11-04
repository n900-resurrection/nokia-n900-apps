#!/bin/bash
# Package the built curl as a .deb ("curl") for Maemo 5. Run INSIDE the Workshop after build.sh:
#   workshop exec n900 -- bash -c 'VERSION=8.23.0 REV=1maemo1 /project/apps/curl/package.sh'
#   (or on the host: make -C apps/curl deb)
# Output: /project/build/deb/curl_<VERSION>-<REV>_armel.deb
#
# Status: verified on a real N900 (2026-11-04): installed, used by git for HTTPS.
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=curl
# CURL_VERSION is the older name of VERSION and is still accepted.
VERSION="${CURL_VERSION:-${VERSION:-8.23.0}}"
MBEDTLS_VERSION="${MBEDTLS_VERSION:-3.6.7}"
OUT="$PROJ/build/out/curl-$VERSION"
SRC="$PROJ/build/src/curl-$VERSION"
MBEDSRC="$PROJ/build/src/mbedtls-$MBEDTLS_VERSION"
STAGE="$PROJ/build/deb/stage-$PKG"

[ -x "$OUT/curl" ] && [ -s "$OUT/cacert.pem" ] || { echo "Missing build output in $OUT, run build.sh first (make build)"; exit 1; }

rm -rf "$STAGE"
mkdir -p "$STAGE/opt/$PKG/bin" "$STAGE/opt/$PKG/etc/ssl" "$STAGE/opt/$PKG/share/doc/$PKG" "$STAGE/usr/bin"

install -m 755 "$OUT/curl" "$STAGE/opt/$PKG/bin/curl"
# Default CA store, compiled into the binary as /opt/curl/etc/ssl/cacert.pem.
install -m 644 "$OUT/cacert.pem" "$STAGE/opt/$PKG/etc/ssl/cacert.pem"
ln -s "../../opt/$PKG/bin/curl" "$STAGE/usr/bin/curl"

# Licenses: curl (curl license), mbedTLS (Apache-2.0 or GPL-2.0-or-later), zlib (zlib license).
install -m 644 "$SRC/COPYING" "$STAGE/opt/$PKG/share/doc/$PKG/COPYING.curl"
[ -f "$MBEDSRC/LICENSE" ] && install -m 644 "$MBEDSRC/LICENSE" "$STAGE/opt/$PKG/share/doc/$PKG/LICENSE.mbedtls"
cat > "$STAGE/opt/$PKG/share/doc/$PKG/README.Maemo" <<EOT
curl $VERSION built for Maemo 5 (armel, glibc 2.5). Upstream: https://curl.se/
Linked statically with mbedTLS $MBEDTLS_VERSION (TLS 1.2/1.3) and a private zlib, so it does not use the
old OpenSSL 0.9.8 of the device (TLS 1.0 only), which cannot talk to modern HTTPS servers.

CA bundle: /opt/curl/etc/ssl/cacert.pem (Mozilla roots, from https://curl.se/ca/cacert.pem, snapshot
of the build date). It is NOT updated automatically; to refresh it:
  curl -o /opt/curl/etc/ssl/cacert.pem https://curl.se/ca/cacert.pem

Randomness: mbedTLS reads /dev/urandom (instead of the default /dev/random, which blocks on this
kernel because it has no getrandom()); see apps/curl/mbedtls-urandom.h in the build repository.

Needs the glibc symbol GLIBC_2.7 (eventfd), which the eglibc 2.5.1-1eglibc27 of Maemo 5 provides.
EOT

SECTION=user/network
DEPENDS="libc6 (>= 2.5.1-1eglibc27)"
DISPLAY_NAME="curl"
SHORT_DESC="Command line tool for transferring data with URLs (TLS 1.3)"
LONG_DESC="curl $VERSION with mbedTLS $MBEDTLS_VERSION, built for Maemo 5. Supports HTTPS with TLS 1.2/1.3,
so it works with servers that the system OpenSSL 0.9.8 of the device cannot talk to.
Installed in /opt/curl, with a link /usr/bin/curl. Upstream: https://curl.se/"
debpack_build
