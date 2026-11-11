#!/bin/bash
# Package the built Profanity as a .deb for Maemo 5. Run INSIDE the Workshop after build.sh: make -C apps/profanity deb
# Output: /project/build/deb/profanity_<VERSION>-<REV>_armel.deb   (a command line tool: no menu entry)
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=profanity
VERSION="${VERSION:-0.19.0}"
OUT="$PROJ/build/out/$PKG-$VERSION"
STAGE="$PROJ/build/deb/stage-$PKG"
[ -x "$OUT/profanity" ] || { echo "Missing build output in $OUT, run build.sh first (make build)"; exit 1; }

rm -rf "$STAGE"; mkdir -p "$STAGE/usr/bin" "$STAGE/opt/profanity/bin" "$STAGE/opt/profanity/share/doc/profanity"
cp -a "$OUT/root/." "$STAGE/"
rm -f "$STAGE/opt/profanity/bin/profanity"
install -m 755 "$OUT/profanity" "$STAGE/opt/profanity/bin/profanity.bin"
# The wrapper points OpenSSL (inside libstrophe) at the CA bundle of the curl package.
cat > "$STAGE/opt/profanity/bin/profanity" <<'WRAP'
#!/bin/sh
# Wrapper: CA certificates for TLS (SSL_CERT_FILE, read by OpenSSL), then the real binary.
[ -n "$SSL_CERT_FILE" ] || export SSL_CERT_FILE=/opt/curl/etc/ssl/cacert.pem
exec /opt/profanity/bin/profanity.bin "$@"
WRAP
chmod 755 "$STAGE/opt/profanity/bin/profanity"
ln -s "../../opt/profanity/bin/profanity" "$STAGE/usr/bin/profanity"
install -m 644 "$OUT/COPYING" "$STAGE/opt/profanity/share/doc/profanity/COPYING"

SECTION=user/network
DEPENDS="libc6 (>= 2.5), curl"
DISPLAY_NAME="Profanity"
SHORT_DESC="Profanity $VERSION XMPP (Jabber) client"
LONG_DESC="Profanity $VERSION: an XMPP (Jabber) client in the terminal. Start it in a terminal (profanity), then /connect user@server.example (it asks for the
password), /msg user@server hello, /join room@conference.server. /help lists the commands. TLS 1.2/1.3 (OpenSSL 3, CA bundle of the curl package; keep the
phone clock correct, ntp-sync). Built for Maemo 5 with static GLib, libstrophe, libcurl, SQLite, readline and ncursesw; no OMEMO, OTR, PGP or plugins.
Upstream: https://profanity-im.github.io"
MAINTAINER="elPytel (build of upstream Profanity by James Booth and contributors)"
debpack_build
