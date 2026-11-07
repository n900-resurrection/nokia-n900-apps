#!/bin/bash
# Package the built tmux as a .deb for Maemo 5. Run INSIDE the Workshop after build.sh: make -C apps/tmux deb
# Output: /project/build/deb/tmux_<VERSION>-<REV>_armel.deb
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=tmux
VERSION="${VERSION:-3.8}"
OUT="$PROJ/build/out/$PKG-$VERSION"
STAGE="$PROJ/build/deb/stage-$PKG"
[ -x "$OUT/root/opt/tmux/bin/tmux" ] || { echo "Missing build output in $OUT, run build.sh first (make build)"; exit 1; }

rm -rf "$STAGE"; mkdir -p "$STAGE/usr/bin"
cp -a "$OUT/root/." "$STAGE/"
ln -s "../../opt/tmux/bin/tmux" "$STAGE/usr/bin/tmux"
mkdir -p "$STAGE/opt/tmux/share/doc/tmux"
install -m 644 "$PROJ/build/src/tmux-$VERSION/COPYING" "$STAGE/opt/tmux/share/doc/tmux/COPYING"
debpack_desktop "tmux" "/usr/bin/tmux" "$PROJ/apps/tmux/icon.png"

SECTION=user/utilities
DEPENDS="libc6 (>= 2.5), libncurses5 (>= 5.7)"
DISPLAY_NAME="tmux"
SHORT_DESC="tmux $VERSION terminal multiplexer"
LONG_DESC="tmux $VERSION for Maemo 5: several terminal windows and panes in one screen, sessions that survive a closed terminal or a lost SSH connection.
Prefix key Ctrl-b (c new window, n/p next/previous, % and \" split, d detach, tmux attach returns). libevent is built in, ncurses comes from the phone.
Upstream: https://github.com/tmux/tmux"
MAINTAINER="elPytel (build of upstream tmux by Nicholas Marriott and contributors)"
debpack_build
