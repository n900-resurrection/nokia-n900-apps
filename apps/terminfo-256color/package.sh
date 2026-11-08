#!/bin/bash
# Package terminfo-256color as a .deb for Maemo 5.
#   make -C apps/terminfo-256color deb
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=terminfo-256color
VERSION="${VERSION:-1.0}"
STAGE="$PROJ/build/deb/stage-$PKG"
SRC="$PROJ/build/terminfo-256color"

bash "$PROJ/apps/terminfo-256color/build.sh" >/dev/null
rm -rf "$STAGE"
mkdir -p "$STAGE/usr/share/terminfo"
cp -a "$SRC"/. "$STAGE/usr/share/terminfo/"
chmod -R u=rwX,go=rX "$STAGE/usr/share/terminfo"

# postinst/postrm manage a marked block in ~user/.bashrc: the 8-colour TERM=xterm of the stock terminal becomes xterm-256color.
mkdir -p "$STAGE/DEBIAN"
cat > "$STAGE/DEBIAN/postinst" <<'EOT'
#!/bin/sh
RC=/home/user/.bashrc
[ "$1" = configure ] || exit 0
[ -f "$RC" ] || exit 0
grep -q 'BEGIN terminfo-256color' "$RC" && exit 0
cat >> "$RC" <<'EOB'
# BEGIN terminfo-256color (package terminfo-256color; removed with the package)
if [ "$TERM" = xterm ] && [ -r /usr/share/terminfo/x/xterm-256color ]; then export TERM=xterm-256color; fi
# END terminfo-256color
EOB
exit 0
EOT
cat > "$STAGE/DEBIAN/postrm" <<'EOT'
#!/bin/sh
RC=/home/user/.bashrc
case "$1" in remove|purge) ;; *) exit 0 ;; esac
[ -f "$RC" ] && sed -i '/# BEGIN terminfo-256color/,/# END terminfo-256color/d' "$RC"
exit 0
EOT
chmod 755 "$STAGE/DEBIAN/postinst" "$STAGE/DEBIAN/postrm"

SECTION=user/system
DEPENDS="ncurses-base"
DISPLAY_NAME="terminfo-256color"
SHORT_DESC="Terminfo for 256-colour terminals (xterm-256color, screen-256color, tmux-256color)"
LONG_DESC="The phone has only 8-colour terminfo entries, so programs that use more colours (ranger, cbonsai, tmux, vim with a colour scheme) fail with: Color number is greater than COLORS-1 (7).
Adds xterm-256color, screen-256color and tmux-256color to /usr/share/terminfo (no system file is replaced). The package adds a small block to /home/user/.bashrc that switches TERM=xterm to xterm-256color (removed with the package); other shells: export TERM=xterm-256color"
debpack_build
