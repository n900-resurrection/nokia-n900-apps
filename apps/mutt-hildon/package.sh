#!/bin/bash
# Package mutt-hildon as a .deb for Maemo 5 (Python scripts). Run INSIDE the Workshop: make -C apps/mutt-hildon deb
# Output: /project/build/deb/mutt-hildon_<VERSION>-<REV>_armel.deb
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=mutt-hildon
VERSION="${VERSION:-0.3}"
STAGE="$PROJ/build/deb/stage-$PKG"
HERE="$PROJ/apps/mutt-hildon"

rm -rf "$STAGE"
mkdir -p "$STAGE/opt/$PKG" "$STAGE/usr/bin" "$STAGE/usr/share/applications/hildon"
install -m 644 "$HERE/mailcore.py" "$STAGE/opt/$PKG/mailcore.py"
install -m 644 "$HERE/store.py" "$STAGE/opt/$PKG/store.py"
install -m 644 "$HERE/selftest.py" "$STAGE/opt/$PKG/selftest.py"
install -m 755 "$HERE/mutt-hildon" "$STAGE/opt/$PKG/mutt-hildon"
for sz in 48 64; do
    mkdir -p "$STAGE/usr/share/icons/hicolor/${sz}x${sz}/apps"
    install -m 644 "$HERE/icons/$sz.png" "$STAGE/usr/share/icons/hicolor/${sz}x${sz}/apps/$PKG.png"
done
ln -s ../../opt/$PKG/mutt-hildon "$STAGE/usr/bin/mutt-hildon"
cat > "$STAGE/usr/share/applications/hildon/$PKG.desktop" <<'EOT'
[Desktop Entry]
Encoding=UTF-8
Version=1.0
Type=Application
Name=Mail (Mutt)
Exec=/usr/bin/mutt-hildon
Icon=mutt-hildon
X-Osso-Type=application/x-executable
EOT

SECTION=user/network
DEPENDS="python2.5, python-gtk2, python2.5-hildon, libsqlite3-0, curl, msmtp, mutt"
DISPLAY_NAME="Mail (Mutt)"
SHORT_DESC="Hildon GUI for the Mutt/msmtp mail setup (IMAP over TLS 1.3)"
LONG_DESC="Finger friendly mail client for Maemo 5: INBOX list, reading, reply and new message. Mail is read with curl (modern TLS) and sent with msmtp, the settings come from ~/.muttrc and ~/.msmtp-password. The menu item Open Mutt starts the full terminal client."
debpack_build
