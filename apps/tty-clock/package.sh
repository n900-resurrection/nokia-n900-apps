#!/bin/bash
# Package the built tty-clock as a .deb for Maemo 5. Run INSIDE the Workshop after build.sh:
#   workshop exec n900 -- bash -c 'VERSION=2.3 REV=1maemo1 /project/apps/tty-clock/package.sh'   (or: make -C apps/tty-clock deb)
# Output: /project/build/deb/tty-clock_<VERSION>-<REV>_armel.deb
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=tty-clock
VERSION="${VERSION:-2.3}"
OUT="$PROJ/build/out/$PKG-$VERSION"
SRC="$PROJ/build/upstream/$PKG"
STAGE="$PROJ/build/deb/stage-$PKG"
[ -x "$OUT/$PKG" ] || { echo "Missing $OUT/$PKG, run build.sh first (make build)"; exit 1; }

rm -rf "$STAGE"
mkdir -p "$STAGE/opt/$PKG/bin" "$STAGE/opt/$PKG/share/man/man1" "$STAGE/opt/$PKG/share/doc/$PKG" "$STAGE/usr/bin"
install -m 755 "$OUT/$PKG" "$STAGE/opt/$PKG/bin/$PKG"
ln -s "../../opt/$PKG/bin/$PKG" "$STAGE/usr/bin/$PKG"
gzip -9n -c "$SRC/tty-clock.1" > "$STAGE/opt/$PKG/share/man/man1/$PKG.1.gz"
# tty-clock has no license file; the BSD 3-clause text is the comment at the top of ttyclock.c.
sed -n '/^ \*      TTY-CLOCK/,/^ \*\//p' "$SRC/ttyclock.c" | sed 's/^ \*\/\?//' > "$STAGE/opt/$PKG/share/doc/$PKG/LICENSE"
install -m 644 "$SRC/README" "$STAGE/opt/$PKG/share/doc/$PKG/README"
debpack_desktop "tty-clock" "/usr/bin/$PKG"

SECTION=user/utilities
# Plain ncurses is enough, and the device already ships libncurses5, so it is a normal dependency.
DEPENDS="libc6 (>= 2.5), libncurses5 (>= 5.7)"
DISPLAY_NAME="tty-clock"
SHORT_DESC="Digital clock for the terminal"
LONG_DESC="tty-clock shows a large digital clock in the terminal. Options: -s seconds, -c centered,
-C <0-7> colour, -t 12 hour format, -b bold, -d <ms> refresh delay.
Built for Maemo 5 (armel, glibc 2.5), dynamically linked against the system libncurses5.
Upstream: https://github.com/xorg62/tty-clock"
debpack_build
