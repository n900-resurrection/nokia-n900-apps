#!/bin/bash
# Package copyparty as a .deb for Maemo 5 (pure Python, built as armel).  make -C apps/copyparty deb
# Output: /project/build/deb/copyparty_<VERSION>-<REV>_armel.deb
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=copyparty
VERSION="${VERSION:-1.20.26}"
STAGE="$PROJ/build/deb/stage-$PKG"
HERE="$PROJ/apps/copyparty"
TREE="$PROJ/build/out/copyparty-$VERSION/tree"

[ -f "$TREE/copyparty/__main__.py" ] || { echo "Missing the unpacked tree ($TREE), run: make -C apps/copyparty build"; exit 1; }
rm -rf "$STAGE"
mkdir -p "$STAGE/opt" "$STAGE/usr/bin" "$STAGE/DEBIAN"
cp -r "$TREE" "$STAGE/opt/copyparty"
install -m 755 "$HERE/copyparty" "$STAGE/usr/bin/copyparty"
install -m 755 "$HERE/copyparty-share" "$STAGE/usr/bin/copyparty-share"
install -m 644 "$HERE/README.md" "$STAGE/opt/copyparty/README.Maemo"
debpack_desktop "File server" copyparty-share "$HERE/icon.png"

# Bytecode is compiled on the phone, for its Python 3.11 (the first start takes 15 to 20 s without it, 3 s with it).
cat > "$STAGE/DEBIAN/postinst" <<'EOT'
#!/bin/sh
case "$1" in configure)
    python3 -m compileall -q /opt/copyparty >/dev/null 2>&1 || true ;;
esac
exit 0
EOT
cat > "$STAGE/DEBIAN/prerm" <<'EOT'
#!/bin/sh
# stop a server that runs in the background, so that its files can go (the settings in ~/.copyparty stay)
case "$1" in remove|upgrade)
    for p in $(pidof python3 2>/dev/null); do
        grep -qs copyparty "/proc/$p/cmdline" && kill "$p" 2>/dev/null || true
    done ;;
esac
exit 0
EOT
cat > "$STAGE/DEBIAN/postrm" <<'EOT'
#!/bin/sh
# dpkg does not know the bytecode files, so it leaves them behind
case "$1" in remove|purge) rm -rf /opt/copyparty ;; esac
exit 0
EOT
chmod 755 "$STAGE/DEBIAN/postinst" "$STAGE/DEBIAN/prerm" "$STAGE/DEBIAN/postrm"

SECTION=user/network
DEPENDS="python3.11"
DISPLAY_NAME="File server"
SHORT_DESC="Share folders of the phone with a web browser (copyparty)"
LONG_DESC="copyparty is a file server in Python: any computer, tablet or phone on the same network opens the address of the N900 in its browser and
downloads or uploads files (also whole folders, with resuming), no software needed there. The menu entry File server starts it in the terminal
and shows the address and the password; the folder MyDocs is shared by default, the user is n900 with a random password
(~/.copyparty/share.conf). Commands: copyparty-share [run|start|stop|status|url|passwd|config], and copyparty with all options of the
upstream program (copyparty --help). Thumbnails and the file index are off (the phone is too small for them).
The server listens on all network connections: use it at home, on a hotspot or over USB networking, and do not expose it to the internet without HTTPS.
Upstream: github.com/9001/copyparty (MIT, by ed)."
debpack_build
