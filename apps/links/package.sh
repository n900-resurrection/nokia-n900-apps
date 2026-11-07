#!/bin/bash
# Package the built links as a .deb for Maemo 5. Run INSIDE the Workshop after build.sh: make -C apps/links deb
# Output: /project/build/deb/links_<VERSION>-<REV>_armel.deb   (menu entry "Links" starts it in the terminal)
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=links
VERSION="${VERSION:-2.30}"
OUT="$PROJ/build/out/$PKG-$VERSION"
STAGE="$PROJ/build/deb/stage-$PKG"
[ -x "$OUT/root/opt/links/bin/links" ] || { echo "Missing build output in $OUT, run build.sh first (make build)"; exit 1; }

rm -rf "$STAGE"; mkdir -p "$STAGE/usr/bin"
cp -a "$OUT/root/." "$STAGE/"
# The wrapper points OpenSSL at a CA bundle (the Mozilla one that the curl build downloads), so that certificates are verified.
CA=$(ls "$PROJ"/build/out/curl-*/cacert.pem | tail -1)
mkdir -p "$STAGE/opt/links/etc"
install -m 644 "$CA" "$STAGE/opt/links/etc/cacert.pem"
cat > "$STAGE/usr/bin/links" <<'EOS'
#!/bin/sh
SSL_CERT_FILE=${SSL_CERT_FILE:-/opt/links/etc/cacert.pem}
export SSL_CERT_FILE
exec /opt/links/bin/links "$@"
EOS
chmod 755 "$STAGE/usr/bin/links"
mkdir -p "$STAGE/opt/links/share/doc/links"
install -m 644 "$PROJ/build/src/links-$VERSION/COPYING" "$STAGE/opt/links/share/doc/links/COPYING"
debpack_desktop "Links" "/usr/bin/links" "$PROJ/apps/links/icon.png"

SECTION=user/network
DEPENDS="libc6 (>= 2.5), zlib1g"
DISPLAY_NAME="Links"
SHORT_DESC="links $VERSION text web browser with TLS 1.3"
LONG_DESC="Links $VERSION, a text mode web browser with menus, tables and frames, for Maemo 5. HTTPS uses a private static OpenSSL 3, so modern
sites (TLS 1.2/1.3) open, unlike in the stock browser. Start it from the menu or with: links https://example.org  (Esc opens the menu).
Certificates are verified against the bundled Mozilla CA list (/opt/links/etc/cacert.pem, override with SSL_CERT_FILE).
Upstream: http://links.twibright.com"
MAINTAINER="elPytel (build of upstream Links by Mikulas Patocka and contributors)"
debpack_build
