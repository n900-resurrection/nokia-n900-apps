#!/bin/bash
# Package the built msmtp as a .deb for Maemo 5. Run INSIDE the Workshop after build.sh: make -C apps/msmtp deb
# Output: /project/build/deb/msmtp_<VERSION>-<REV>_armel.deb
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=msmtp
VERSION="${VERSION:-1.8.34}"
OUT="$PROJ/build/out/$PKG-$VERSION"
SRC="$PROJ/build/src/$PKG-$VERSION"
STAGE="$PROJ/build/deb/stage-$PKG"
[ -x "$OUT/$PKG" ] || { echo "Missing $OUT/$PKG, run build.sh first (make build)"; exit 1; }

rm -rf "$STAGE"
mkdir -p "$STAGE/opt/$PKG/bin" "$STAGE/opt/$PKG/share/doc/$PKG" "$STAGE/usr/bin"
install -m 755 "$OUT/$PKG" "$STAGE/opt/$PKG/bin/$PKG"
ln -s "../../opt/$PKG/bin/$PKG" "$STAGE/usr/bin/$PKG"
install -m 644 "$SRC/COPYING" "$STAGE/opt/$PKG/share/doc/$PKG/COPYING"
install -m 644 "$PROJ/apps/msmtp/msmtprc.centrum.example" "$STAGE/opt/$PKG/share/doc/$PKG/msmtprc.centrum.example"
cat > "$STAGE/opt/$PKG/share/doc/$PKG/README.Maemo" <<EOT
msmtp $VERSION built for Maemo 5 (armel, glibc 2.5). Upstream: https://marlam.de/msmtp/
SMTP client with TLS 1.2/1.3 (statically linked OpenSSL 3). Used as the "sendmail" of Mutt:
  set sendmail = "/usr/bin/msmtp -a centrum"
Example configuration (no password): /opt/msmtp/share/doc/msmtp/msmtprc.centrum.example, copy it to ~/.msmtprc (chmod 600).
CA bundle: /opt/curl/etc/ssl/cacert.pem (package curl).
EOT

SECTION=user/network
DEPENDS="libc6 (>= 2.5), curl"
DISPLAY_NAME="msmtp"
SHORT_DESC="msmtp $VERSION SMTP client (TLS 1.3), sendmail replacement"
LONG_DESC="msmtp $VERSION for Maemo 5 with OpenSSL 3. Sends mail through an SMTP server with login over TLS,
for example smtp.centrum.cz port 465. Mutt needs it because Mutt without Cyrus SASL cannot log in to SMTP.
Installed in /opt/msmtp, link /usr/bin/msmtp."
debpack_build
