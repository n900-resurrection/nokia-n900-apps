#!/bin/bash
# Package the echo protocol plugin as a .deb for Maemo 5. Run INSIDE the Workshop after build.sh: make -C apps/purple-echo deb
# Output: /project/build/deb/purple-echo_<VERSION>-<REV>_armel.deb
# The package adds a protocol "echo" to telepathy-haze: the plugin in /usr/lib/purple-2, a [Protocol echo] block in
# /usr/share/telepathy/managers/haze.manager (added by postinst, removed by postrm; a backup is kept) and the account profile.
# Nothing is restarted: the Mission Control daemon reads the manager files at start (log out/in or reboot, see the description).
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=purple-echo
VERSION="${VERSION:-0.1}"
OUT="$PROJ/build/out/$PKG-$VERSION"
STAGE="$PROJ/build/deb/stage-$PKG"
[ -f "$OUT/libecho.so" ] || { echo "Missing build output in $OUT, run build.sh first (make build)"; exit 1; }

rm -rf "$STAGE"
mkdir -p "$STAGE/opt/purple-echo/lib" "$STAGE/opt/purple-echo/share/doc/purple-echo" "$STAGE/usr/lib/purple-2" \
    "$STAGE/usr/share/osso-rtcom" "$STAGE/usr/share/icons/hicolor/48x48/hildon" "$STAGE/DEBIAN"
install -m 755 "$OUT/libecho.so" "$STAGE/opt/purple-echo/lib/libecho.so"
ln -s /opt/purple-echo/lib/libecho.so "$STAGE/usr/lib/purple-2/libecho.so"
install -m 644 "$OUT/COPYING" "$STAGE/opt/purple-echo/share/doc/purple-echo/COPYING"

# the profile follows icq.profile of account-plugin-haze
sed -e 's/^Protocol=icq/Protocol=echo/' -e 's/^IconName = im-icq/IconName = im-echo/' -e 's/^DisplayName=ICQ/DisplayName=Echo (test)/' \
    -e '/^VCard/d' -e 's/^Capabilities = .*/Capabilities = chat-p2p, supports-alias/' \
    "$PROJ/apps/purple-echo/echo.profile" > "$STAGE/usr/share/osso-rtcom/echo.profile"

# a plain speech bubble icon (no font needed)
convert -size 48x48 xc:none -fill '#4a90d9' -draw 'roundrectangle 4,6 43,34 8,8' -draw 'polygon 12,32 12,43 24,33' \
    -fill white -draw 'circle 15,20 15,23' -draw 'circle 24,20 24,23' -draw 'circle 33,20 33,23' \
    "$STAGE/usr/share/icons/hicolor/48x48/hildon/im-echo.png"

cat > "$STAGE/opt/purple-echo/share/haze-echo.manager" <<'EOT'
# BEGIN purple-echo
[Protocol echo]
param-account=s required
# END purple-echo
EOT

cat > "$STAGE/DEBIAN/postinst" <<'EOT'
#!/bin/sh
# Add the protocol to the haze manager file once (the original is kept as haze.manager.orig-echo). Nothing is restarted.
M=/usr/share/telepathy/managers/haze.manager
[ -f "$M" ] || exit 0
if ! grep -q 'BEGIN purple-echo' "$M"; then
    [ -f "$M.orig-echo" ] || cp -p "$M" "$M.orig-echo"
    { echo; cat /opt/purple-echo/share/haze-echo.manager; } >> "$M"
fi
gtk-update-icon-cache -f /usr/share/icons/hicolor >/dev/null 2>&1 || true
echo "purple-echo: restart Mission Control (or reboot) so that the new protocol appears in Settings > Accounts."
exit 0
EOT
cat > "$STAGE/DEBIAN/postrm" <<'EOT'
#!/bin/sh
# Remove the block from the haze manager file again.
M=/usr/share/telepathy/managers/haze.manager
if [ -f "$M" ] && grep -q 'BEGIN purple-echo' "$M"; then
    sed -i '/BEGIN purple-echo/,/END purple-echo/d' "$M"
fi
gtk-update-icon-cache -f /usr/share/icons/hicolor >/dev/null 2>&1 || true
exit 0
EOT
chmod 755 "$STAGE/DEBIAN/postinst" "$STAGE/DEBIAN/postrm"

SECTION=user/network
DEPENDS="libc6 (>= 2.5), libpurple0, telepathy-haze"
DISPLAY_NAME="purple-echo"
SHORT_DESC="Echo test protocol for the Maemo messaging UI (libpurple/haze)"
LONG_DESC="A test protocol (step 0 of the native Signal plan): a libpurple plugin with one contact, echo-bot, that answers every message with \"Echo: <text>\". It adds the protocol \"Echo (test)\" to telepathy-haze (haze.manager block, account profile, icon) to check that Settings > Accounts and Conversations show a protocol from a third-party plugin.
The Mission Control daemon reads the manager files at start: restart it or reboot after installing. Remove the package to undo (the haze.manager block is removed, a backup is kept as haze.manager.orig-echo)."
MAINTAINER="elPytel"
debpack_build
