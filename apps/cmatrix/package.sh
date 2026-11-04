#!/bin/bash
# Package the built cmatrix as a .deb for Maemo 5. Run INSIDE the Workshop after build.sh:
#   workshop exec n900 -- bash -c 'VERSION=2.0 REV=1maemo1 /project/apps/cmatrix/package.sh'   (or: make -C apps/cmatrix deb)
# Output: /project/build/deb/cmatrix_<VERSION>-<REV>_armel.deb
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=cmatrix
VERSION="${VERSION:-2.0}"
OUT="$PROJ/build/out/$PKG-$VERSION"
SRC="$PROJ/build/upstream/$PKG"
STAGE="$PROJ/build/deb/stage-$PKG"
[ -x "$OUT/$PKG" ] || { echo "Missing $OUT/$PKG, run build.sh first (make build)"; exit 1; }

rm -rf "$STAGE"
mkdir -p "$STAGE/opt/$PKG/bin" "$STAGE/opt/$PKG/share/man/man1" "$STAGE/opt/$PKG/share/doc/$PKG" "$STAGE/usr/bin"
install -m 755 "$OUT/$PKG" "$STAGE/opt/$PKG/bin/$PKG"
ln -s "../../opt/$PKG/bin/$PKG" "$STAGE/usr/bin/$PKG"
gzip -9n -c "$SRC/cmatrix.1" > "$STAGE/opt/$PKG/share/man/man1/$PKG.1.gz"
install -m 644 "$SRC/COPYING" "$STAGE/opt/$PKG/share/doc/$PKG/COPYING"
install -m 644 "$SRC/README" "$STAGE/opt/$PKG/share/doc/$PKG/README"
debpack_desktop "CMatrix" "/usr/bin/$PKG"

SECTION=user/other
# Plain ncurses is enough, and the device already ships libncurses5, so it is a normal dependency.
DEPENDS="libc6 (>= 2.5), libncurses5 (>= 5.7)"
DISPLAY_NAME="CMatrix"
SHORT_DESC="Matrix-style falling characters in the terminal"
LONG_DESC="cmatrix shows scrolling characters like in the movie The Matrix. Press q to quit.
Options: -b bold, -C <colour>, -s screensaver mode (any key quits), -u <0-10> speed.
Built for Maemo 5 (armel, glibc 2.5), dynamically linked against the system libncurses5.
Upstream: https://github.com/abishekvashok/cmatrix"
debpack_build
