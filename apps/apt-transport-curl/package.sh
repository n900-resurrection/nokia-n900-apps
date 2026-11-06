#!/bin/bash
# Package apt-transport-curl (apt method "https" over curl) as a .deb for Maemo 5.
#   make -C apps/apt-transport-curl deb
# The method file of the system package apt-transport-https is diverted (dpkg-divert) and restored on removal.
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=apt-transport-curl
VERSION="${VERSION:-0.1}"
STAGE="$PROJ/build/deb/stage-$PKG"
HERE="$PROJ/apps/apt-transport-curl"
M=/usr/lib/apt/methods

rm -rf "$STAGE"
mkdir -p "$STAGE$M" "$STAGE/DEBIAN"
install -m 755 "$HERE/https" "$STAGE$M/https"
cat > "$STAGE/DEBIAN/preinst" <<EOT
#!/bin/sh
set -e
if [ "\$1" = install ] || [ "\$1" = upgrade ]; then
    dpkg-divert --package $PKG --rename --divert $M/https.distrib --add $M/https
fi
exit 0
EOT
cat > "$STAGE/DEBIAN/postrm" <<EOT
#!/bin/sh
set -e
if [ "\$1" = remove ] || [ "\$1" = abort-install ] || [ "\$1" = abort-upgrade ]; then
    rm -f $M/https
    dpkg-divert --package $PKG --rename --remove $M/https
fi
exit 0
EOT
chmod 755 "$STAGE/DEBIAN/preinst" "$STAGE/DEBIAN/postrm"

SECTION=user/system
DEPENDS="curl, apt-transport-https"
DISPLAY_NAME="apt-transport-curl"
SHORT_DESC="apt over HTTPS with TLS 1.2/1.3 (through curl 8)"
LONG_DESC="Replaces the apt method /usr/lib/apt/methods/https (old libcurl with OpenSSL 0.9.8, TLS 1.0 only) by a script that runs /usr/bin/curl. Repositories on GitHub Pages and other modern HTTPS servers then work with apt and the Application Manager.
The original method is kept as https.distrib and restored when the package is removed. Certificates are always verified (CA bundle of the curl package); Acquire::https::Curl-Insecure \"true\" turns it off, Acquire::https::CaInfo selects another bundle."
debpack_build
