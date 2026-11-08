#!/bin/bash
# Package the Signal protocol plugin as a .deb for Maemo 5. Run INSIDE the Workshop after build.sh: make -C apps/libsignal-purple deb
# Output: /project/build/deb/libsignal-purple_<VERSION>-<REV>_armel.deb
# Adds the protocol "signal" to telepathy-haze (plugin in /usr/lib/purple-2, a [Protocol signal] block in haze.manager added by
# postinst and removed by postrm, the account profile and an icon). Nothing is restarted: Mission Control reads the manager files at start.
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=libsignal-purple
VERSION="${VERSION:-0.1}"
OUT="$PROJ/build/out/$PKG-$VERSION"
STAGE="$PROJ/build/deb/stage-$PKG"
[ -f "$OUT/libsignal.so" ] || { echo "Missing build output in $OUT, run build.sh first (make build)"; exit 1; }

rm -rf "$STAGE"
mkdir -p "$STAGE/opt/libsignal-purple/lib" "$STAGE/opt/libsignal-purple/share/doc/libsignal-purple" "$STAGE/usr/lib/purple-2" \
    "$STAGE/usr/share/osso-rtcom" "$STAGE/usr/share/icons/hicolor/48x48/hildon" "$STAGE/DEBIAN"
install -m 755 "$OUT/libsignal.so" "$STAGE/opt/libsignal-purple/lib/libsignal.so"
ln -s /opt/libsignal-purple/lib/libsignal.so "$STAGE/usr/lib/purple-2/libsignal.so"
install -m 644 "$OUT/COPYING" "$STAGE/opt/libsignal-purple/share/doc/libsignal-purple/COPYING"

# the profile follows icq.profile of account-plugin-haze (apps/libsignal-purple/signal.profile is a copy of it)
sed -e 's/^Protocol=icq/Protocol=signal/' -e 's/^IconName = im-icq/IconName = im-signal/' -e 's/^DisplayName=ICQ/DisplayName=Signal/' \
    -e '/^VCard/d' -e 's/^Capabilities = .*/Capabilities = chat-p2p, supports-alias, supports-roster/' \
    "$PROJ/apps/libsignal-purple/signal.profile" > "$STAGE/usr/share/osso-rtcom/signal.profile"

# a blue speech bubble (no font needed)
convert -size 48x48 xc:none -fill '#3a76f0' -draw 'roundrectangle 2,2 45,45 10,10' \
    -fill white -draw 'ellipse 24,22 14,12 0,360' -draw 'polygon 13,28 9,40 22,33' \
    -fill '#3a76f0' -draw 'circle 18,22 18,24' -draw 'circle 24,22 24,24' -draw 'circle 30,22 30,24' \
    "$STAGE/usr/share/icons/hicolor/48x48/hildon/im-signal.png"

cat > "$STAGE/opt/libsignal-purple/share/haze-signal.manager" <<'EOT'
# BEGIN libsignal-purple
[Protocol signal]
param-account=s required
# END libsignal-purple
EOT

cat > "$STAGE/DEBIAN/postinst" <<'EOT'
#!/bin/sh
# Add the protocol to the haze manager file once (the original is kept as haze.manager.orig-signal). Nothing is restarted.
M=/usr/share/telepathy/managers/haze.manager
[ -f "$M" ] || exit 0
if ! grep -q 'BEGIN libsignal-purple' "$M"; then
    [ -f "$M.orig-signal" ] || cp -p "$M" "$M.orig-signal"
    { echo; cat /opt/libsignal-purple/share/haze-signal.manager; } >> "$M"
fi
gtk-update-icon-cache -f /usr/share/icons/hicolor >/dev/null 2>&1 || true
echo "libsignal-purple: restart Mission Control (or reboot) so that Signal appears in Settings > Accounts."
exit 0
EOT
cat > "$STAGE/DEBIAN/postrm" <<'EOT'
#!/bin/sh
M=/usr/share/telepathy/managers/haze.manager
if [ -f "$M" ] && grep -q 'BEGIN libsignal-purple' "$M"; then
    sed -i '/BEGIN libsignal-purple/,/END libsignal-purple/d' "$M"
fi
gtk-update-icon-cache -f /usr/share/icons/hicolor >/dev/null 2>&1 || true
exit 0
EOT
chmod 755 "$STAGE/DEBIAN/postinst" "$STAGE/DEBIAN/postrm"

SECTION=user/network
DEPENDS="libc6 (>= 2.5), libpurple0, telepathy-haze, signal-bridge"
DISPLAY_NAME="Signal (libpurple plugin)"
SHORT_DESC="Signal in the Maemo messaging UI (libpurple plugin over signal-bridge)"
LONG_DESC="A libpurple protocol plugin that shows Signal as an account in Settings > Accounts and the chats in Conversations. It does no cryptography: it talks to the signal-bridge daemon, which it starts when needed (first connection takes about a minute). The device must be linked first (for example with gurk); do not run gurk at the same time as the account is online.
Restart Mission Control or reboot after installing. Remove the package to undo (the haze.manager block is removed, a backup is kept as haze.manager.orig-signal)."
MAINTAINER="elPytel"
debpack_build
