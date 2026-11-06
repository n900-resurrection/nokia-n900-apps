#!/bin/bash
# Package the built Mutt as a .deb for Maemo 5. Run INSIDE the Workshop after build.sh: make -C apps/mutt deb
# Output: /project/build/deb/mutt_<VERSION>-<REV>_armel.deb
# Called "mutt" on purpose: it replaces the mutt 1.5.20 of the Fremantle repository (TLS 1.0 only).
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=mutt
VERSION="${VERSION:-2.4.3}"
OUT="$PROJ/build/out/$PKG-$VERSION"
SRC="$PROJ/build/src/$PKG-$VERSION"
STAGE="$PROJ/build/deb/stage-$PKG"
[ -x "$OUT/$PKG" ] || { echo "Missing $OUT/$PKG, run build.sh first (make build)"; exit 1; }

rm -rf "$STAGE"
mkdir -p "$STAGE/opt/$PKG/bin" "$STAGE/opt/$PKG/etc" "$STAGE/opt/$PKG/share/doc/$PKG" "$STAGE/usr/bin"
install -m 755 "$OUT/$PKG" "$STAGE/opt/$PKG/bin/$PKG"
ln -s "../../opt/$PKG/bin/$PKG" "$STAGE/usr/bin/$PKG"
install -m 644 "$SRC/COPYRIGHT" "$STAGE/opt/$PKG/share/doc/$PKG/COPYRIGHT"
install -m 644 "$PROJ/apps/mutt/muttrc.centrum.example" "$STAGE/opt/$PKG/share/doc/$PKG/muttrc.centrum.example"
cat > "$STAGE/opt/$PKG/share/doc/$PKG/README.Maemo" <<EOT
Mutt $VERSION built for Maemo 5 (armel, glibc 2.5). Upstream: http://www.mutt.org/
TLS 1.2/1.3 through a statically linked OpenSSL 3, IMAP and POP3 built in, sending through msmtp (no SASL, no GPGME, no header cache).
Wide-character ncurses is linked statically, so UTF-8 works. Example configuration for Centrum:
/opt/mutt/share/doc/mutt/muttrc.centrum.example (copy it to ~/.muttrc and edit; it holds no password).
CA bundle: /opt/curl/etc/ssl/cacert.pem (package curl), reached through the link /opt/openssl/etc/ssl/cert.pem. The clock must be correct for certificate checks (ntp-sync).
EOT
# The OpenSSL inside mutt looks for its CA file in /opt/openssl/etc/ssl/cert.pem (compiled-in default).
# Point it to the bundle of the curl package.
mkdir -p "$STAGE/opt/openssl/etc/ssl"
ln -s ../../../curl/etc/ssl/cacert.pem "$STAGE/opt/openssl/etc/ssl/cert.pem"
debpack_desktop "Mutt" "/usr/bin/$PKG" "$PROJ/apps/mutt/icon.png"

SECTION=user/network
DEPENDS="libc6 (>= 2.5), curl, msmtp"
DISPLAY_NAME="Mutt"
SHORT_DESC="Mutt $VERSION terminal e-mail client (IMAP/SMTP over TLS 1.3)"
LONG_DESC="Mutt $VERSION for Maemo 5 with OpenSSL 3, so it can talk to servers that require TLS 1.2 or newer
(for example Centrum). Replaces the old mutt 1.5.20. Installed in /opt/mutt, link /usr/bin/mutt.
Example configuration: /opt/mutt/share/doc/mutt/muttrc.centrum.example."
debpack_build
