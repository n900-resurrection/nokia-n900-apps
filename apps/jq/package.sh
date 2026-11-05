#!/bin/bash
# Package the built jq as a .deb for Maemo 5. Run INSIDE the Workshop after build.sh: make -C apps/jq deb
# Output: /project/build/deb/jq_<VERSION>-<REV>_armel.deb
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=jq
VERSION="${VERSION:-1.8.2}"
OUT="$PROJ/build/out/$PKG-$VERSION"
SRC="$PROJ/build/src/$PKG-$VERSION"
STAGE="$PROJ/build/deb/stage-$PKG"
[ -x "$OUT/$PKG" ] || { echo "Missing $OUT/$PKG, run build.sh first (make build)"; exit 1; }

rm -rf "$STAGE"
mkdir -p "$STAGE/opt/$PKG/bin" "$STAGE/opt/$PKG/share/doc/$PKG" "$STAGE/usr/bin"
install -m 755 "$OUT/$PKG" "$STAGE/opt/$PKG/bin/$PKG"
ln -s "../../opt/$PKG/bin/$PKG" "$STAGE/usr/bin/$PKG"
install -m 644 "$SRC/COPYING" "$STAGE/opt/$PKG/share/doc/$PKG/COPYING"

SECTION=user/utilities
DEPENDS="libc6 (>= 2.5)"
DISPLAY_NAME="jq"
SHORT_DESC="Command-line JSON processor"
LONG_DESC="jq $VERSION built for Maemo 5 (armel, glibc 2.5). Filters and transforms JSON,
used for example with the Audiobookshelf API. Regular expressions via the bundled oniguruma.
Upstream: https://jqlang.org/"
debpack_build
