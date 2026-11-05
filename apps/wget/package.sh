#!/bin/bash
# Package the built Wget as a .deb ("wget") for Maemo 5. Run INSIDE the Workshop: make -C apps/wget deb
# Output: /project/build/deb/wget_<VERSION>-<REV>_armel.deb
# The package is called "wget" on purpose: it upgrades the old wget 1.10.2 (TLS 1.0 only) of the device.
# To go back: install the old wget_1.10.2-2osso3_armel.deb again.
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=wget
VERSION="${VERSION:-1.25.0}"
OUT="$PROJ/build/out/$PKG-$VERSION"
SRC="$PROJ/build/src/$PKG-$VERSION"
STAGE="$PROJ/build/deb/stage-$PKG"
[ -x "$OUT/$PKG" ] || { echo "Missing $OUT/$PKG, run build.sh first (make build)"; exit 1; }

rm -rf "$STAGE"
mkdir -p "$STAGE/opt/$PKG/bin" "$STAGE/opt/$PKG/etc" "$STAGE/opt/$PKG/share/doc/$PKG" "$STAGE/usr/bin"
install -m 755 "$OUT/$PKG" "$STAGE/opt/$PKG/bin/$PKG"
ln -s "../../opt/$PKG/bin/$PKG" "$STAGE/usr/bin/$PKG"
install -m 644 "$SRC/COPYING" "$STAGE/opt/$PKG/share/doc/$PKG/COPYING"
cat > "$STAGE/opt/$PKG/etc/wgetrc" <<'EOT'
# System wgetrc of /opt/wget. The CA bundle comes with the "curl" package.
ca_certificate = /opt/curl/etc/ssl/cacert.pem
EOT
mkdir -p "$STAGE/DEBIAN"
echo /opt/wget/etc/wgetrc > "$STAGE/DEBIAN/conffiles"
cat > "$STAGE/opt/$PKG/share/doc/$PKG/README.Maemo" <<EOT
GNU Wget $VERSION built for Maemo 5 (armel, glibc 2.5). Upstream: https://www.gnu.org/software/wget/
TLS 1.2/1.3 through a statically linked OpenSSL 3, so it works with modern HTTPS servers (the old
wget 1.10 of the device cannot). CA bundle: /opt/curl/etc/ssl/cacert.pem (package curl), set in
/opt/wget/etc/wgetrc. Built without IPv6, IDN, PCRE and gettext.
EOT

SECTION=user/network
DEPENDS="libc6 (>= 2.5), curl"
DISPLAY_NAME="Wget"
SHORT_DESC="GNU Wget $VERSION (HTTPS with TLS 1.3)"
LONG_DESC="GNU Wget $VERSION for Maemo 5, linked with OpenSSL 3. Upgrades wget 1.10.2 of the device.
Installed in /opt/wget, with a link /usr/bin/wget. Certificates: /opt/curl/etc/ssl/cacert.pem."
debpack_build
