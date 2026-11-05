#!/bin/bash
# Package camel-lite with OpenSSL 3 as a .deb for Maemo 5: make -C apps/camel-lite deb
# Output: /project/build/deb/camel-lite-ssl3_<VERSION>-<REV>_armel.deb
#
# The files live in /opt/camel-lite3. The postinst replaces the system libcamel-lite and the mail providers with
# symlinks to them (the originals are kept as *.nss-orig), the prerm puts the originals back. So `dpkg -r` is a
# complete way back. Modest has to be restarted after install/remove (it keeps the old library in memory).
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=camel-lite-ssl3
VERSION="${VERSION:-1.1.92cssu7}"
OUT="$PROJ/build/out/camel-lite-$VERSION"
STAGE="$PROJ/build/deb/stage-$PKG"
ROOT="$OUT/root"
[ -s "$ROOT/usr/lib/libcamel-lite-1.2.so.0.0.0" ] || { echo "Missing build output, run: make -C apps/camel-lite build"; exit 1; }

rm -rf "$STAGE"
D="$STAGE/opt/camel-lite3"
mkdir -p "$D/lib" "$D/providers" "$D/bin" "$D/share/doc/camel-lite3" "$STAGE/DEBIAN"
install -m 755 "$ROOT/usr/lib/libcamel-lite-1.2.so.0.0.0" "$D/lib/"
for p in imap smtp pop3 local nntp sendmail; do
    install -m 755 "$ROOT/usr/lib/camel-lite-1.2/camel-providers/libcamel$p.so" "$D/providers/"
done
install -m 755 "$ROOT/opt/camel-lite3/bin/camel-tlstest" "$D/bin/"
install -m 644 "$PROJ/build/src/camel-lite-$VERSION/COPYING" "$D/share/doc/camel-lite3/COPYING"
cat > "$D/share/doc/camel-lite3/README.Maemo" <<'EOT'
camel-lite (mail library of Modest, community-ssu/tinymail 1.1.92cssu7) with the OpenSSL backend ported to OpenSSL 3.5
(linked statically), so Modest can use TLS 1.2/1.3. The system libraries are replaced by symlinks to /opt/camel-lite3,
the originals are kept as *.nss-orig and restored by `dpkg -r camel-lite-ssl3`. Restart Modest after install/remove.
Test without an account: /opt/camel-lite3/bin/camel-tlstest imap.centrum.cz 993
EOT

cat > "$STAGE/DEBIAN/postinst" <<'EOT'
#!/bin/sh
# Replace the system camel-lite by ours (symlinks); keep the originals.
set -e
L=/usr/lib
P=/usr/lib/camel-lite-1.2/camel-providers
swap() {  # swap <system file> <our file>
    if [ -f "$1" ] && [ ! -L "$1" ] && [ ! -e "$1.nss-orig" ]; then mv "$1" "$1.nss-orig"; fi
    ln -sf "$2" "$1"
}
swap $L/libcamel-lite-1.2.so.0.0.0 /opt/camel-lite3/lib/libcamel-lite-1.2.so.0.0.0
for p in imap smtp pop3 local nntp sendmail; do swap $P/libcamel$p.so /opt/camel-lite3/providers/libcamel$p.so; done
# Safety net: every consumer of the library must find all its symbols (a missing one kills Modest at start).
bad=$(ldd -r /usr/lib/libtinymail-camel-1.0.so.0 /usr/lib/camel-lite-1.2/camel-providers/libcamelimap.so \
          /usr/lib/camel-lite-1.2/camel-providers/libcamelas.so 2>&1 | grep -c "undefined symbol" || true)
if [ "$bad" != "0" ]; then
    echo "camel-lite-ssl3: $bad undefined symbols with the new library, restoring the originals" >&2
    rm -f $L/libcamel-lite-1.2.so.0.0.0; mv $L/libcamel-lite-1.2.so.0.0.0.nss-orig $L/libcamel-lite-1.2.so.0.0.0
    for p in imap smtp pop3 local nntp sendmail; do
        rm -f $P/libcamel$p.so; [ -e $P/libcamel$p.so.nss-orig ] && mv $P/libcamel$p.so.nss-orig $P/libcamel$p.so
    done
    exit 1
fi
echo "camel-lite-ssl3: installed. Restart Modest (close it and open again)."
exit 0
EOT
cat > "$STAGE/DEBIAN/prerm" <<'EOT'
#!/bin/sh
# Put the original NSS based libraries back.
L=/usr/lib
P=/usr/lib/camel-lite-1.2/camel-providers
back() {
    if [ -e "$1.nss-orig" ]; then rm -f "$1"; mv "$1.nss-orig" "$1"; fi
}
back $L/libcamel-lite-1.2.so.0.0.0
for p in imap smtp pop3 local nntp sendmail; do back $P/libcamel$p.so; done
echo "camel-lite-ssl3: originals restored. Restart Modest."
exit 0
EOT
chmod 755 "$STAGE/DEBIAN/postinst" "$STAGE/DEBIAN/prerm"

SECTION=user/network
DEPENDS="libc6 (>= 2.5), libglib2.0-0, zlib1g, libtinymail-camel-1.0-0"
DISPLAY_NAME="Modest TLS 1.3 (camel-lite)"
SHORT_DESC="camel-lite with OpenSSL 3: Modest with TLS 1.2/1.3 (replaces the system library, reversible)"
LONG_DESC="The mail library of the Modest e-mail client rebuilt with OpenSSL 3.5 (static) instead of the NSS 3.12 of the browser, which knows TLS 1.0 only. Servers such as Centrum (imap.centrum.cz, smtp.centrum.cz) then work in Modest. The system library is replaced by links, dpkg -r restores the originals. Restart Modest after install and remove."
debpack_build
