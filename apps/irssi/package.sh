#!/bin/bash
# Package the built irssi as a .deb for Maemo 5. Run INSIDE the Workshop after build.sh: make -C apps/irssi deb
# Output: /project/build/deb/irssi_<VERSION>-<REV>_armel.deb   (a command line tool: no menu entry)
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=irssi
VERSION="${VERSION:-1.4.5}"
OUT="$PROJ/build/out/$PKG-$VERSION"
STAGE="$PROJ/build/deb/stage-$PKG"
[ -x "$OUT/irssi" ] || { echo "Missing build output in $OUT, run build.sh first (make build)"; exit 1; }

rm -rf "$STAGE"; mkdir -p "$STAGE/usr/bin" "$STAGE/opt/irssi/bin" "$STAGE/opt/irssi/share/doc/irssi"
# Without headers and the pkg-config file (only needed to build plugins)
cp -a "$OUT/root/." "$STAGE/"
rm -rf "$STAGE/opt/irssi/include" "$STAGE/opt/irssi/lib" "$STAGE/opt/irssi/bin/irssi"
install -m 755 "$OUT/irssi" "$STAGE/opt/irssi/bin/irssi.bin"
# The wrapper points OpenSSL at the CA bundle of the curl package (OpenSSL 3 inside irssi has no system store).
cat > "$STAGE/opt/irssi/bin/irssi" <<'WRAP'
#!/bin/sh
# Wrapper: CA certificates for TLS (irssi's /connect -tls), then the real binary.
[ -n "$SSL_CERT_FILE" ] || export SSL_CERT_FILE=/opt/curl/etc/ssl/cacert.pem
exec /opt/irssi/bin/irssi.bin "$@"
WRAP
chmod 755 "$STAGE/opt/irssi/bin/irssi"
ln -s "../../opt/irssi/bin/irssi" "$STAGE/usr/bin/irssi"
install -m 644 "$OUT/COPYING" "$STAGE/opt/irssi/share/doc/irssi/COPYING"

SECTION=user/network
DEPENDS="libc6 (>= 2.5), curl"
DISPLAY_NAME="irssi"
SHORT_DESC="irssi $VERSION IRC client"
LONG_DESC="irssi $VERSION: the IRC client in the terminal. Start it in a terminal (irssi), then /connect -tls irc.libera.chat 6697, /join #channel,
/help lists the commands. TLS 1.2/1.3 works (OpenSSL 3, CA bundle of the curl package; keep the phone clock correct, ntp-sync).
Built for Maemo 5 with static GLib 2.66, OpenSSL 3 and ncursesw (UTF-8), no Perl. Upstream: https://irssi.org"
MAINTAINER="elPytel (build of upstream irssi by the Irssi project)"
debpack_build
