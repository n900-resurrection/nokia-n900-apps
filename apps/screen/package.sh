#!/bin/bash
# Package the built screen as a .deb for Maemo 5. Run INSIDE the Workshop after build.sh: make -C apps/screen deb
# Output: /project/build/deb/screen_<VERSION>-<REV>_armel.deb   (a command line tool: no menu entry)
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=screen
VERSION="${VERSION:-5.0.2}"
OUT="$PROJ/build/out/$PKG-$VERSION"
STAGE="$PROJ/build/deb/stage-$PKG"
[ -x "$OUT/root/opt/screen/bin/screen" ] || { echo "Missing build output in $OUT, run build.sh first (make build)"; exit 1; }

rm -rf "$STAGE"; mkdir -p "$STAGE/usr/bin" "$STAGE/opt/screen/share/doc/screen"
cp -a "$OUT/root/." "$STAGE/"
ln -s "../../opt/screen/bin/screen" "$STAGE/usr/bin/screen"
install -m 644 "$OUT/COPYING" "$STAGE/opt/screen/share/doc/screen/COPYING"
# system-wide defaults: no start-up message, a bigger scrollback, a status line with the window list
cat > "$STAGE/opt/screen/etc/screenrc" <<'EOT'
startup_message off
defscrollback 5000
termcapinfo xterm* ti@:te@
caption always "%{= kw}%-w%{= bw}%n %t%{-}%+w %=%H %c"
EOT

SECTION=user/utilities
DEPENDS="libc6 (>= 2.5), libncurses5"
DISPLAY_NAME="screen"
SHORT_DESC="GNU screen $VERSION terminal multiplexer"
LONG_DESC="GNU screen $VERSION: several programs in one terminal, detach and reattach later (screen, Ctrl-A d to detach, screen -r to come back, Ctrl-A c a new window,
Ctrl-A n/p next/previous, Ctrl-A [ scrollback). An alternative to tmux for people who know it. Sockets go to ~/.screen. Defaults in /opt/screen/etc/screenrc.
Built for Maemo 5 with the ncurses of the phone. Upstream: https://www.gnu.org/software/screen"
MAINTAINER="elPytel (build of GNU screen)"
debpack_build
