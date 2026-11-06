#!/bin/bash
# Package QuickJS as a .deb for Maemo 5. Run INSIDE the Workshop after build.sh: make -C apps/quickjs deb
# Output: /project/build/deb/quickjs_<VERSION>-<REV>_armel.deb
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=quickjs
VERSION="${VERSION:-2026-06-04}"
DEBVER="${VERSION//-/.}"        # Debian versions: 2026.06.04
OUT="$PROJ/build/out/$PKG-$VERSION"
STAGE="$PROJ/build/deb/stage-$PKG"
[ -x "$OUT/qjs" ] || { echo "Missing $OUT/qjs, run build.sh first (make build)"; exit 1; }

rm -rf "$STAGE"
mkdir -p "$STAGE/opt/$PKG/bin" "$STAGE/opt/$PKG/share/doc/$PKG" "$STAGE/usr/bin"
install -m 755 "$OUT/qjs" "$STAGE/opt/$PKG/bin/qjs"
ln -s "../../opt/$PKG/bin/qjs" "$STAGE/usr/bin/qjs"
install -m 644 "$OUT/LICENSE" "$STAGE/opt/$PKG/share/doc/$PKG/LICENSE"

VERSION="$DEBVER"
SECTION=user/development
DEPENDS="libc6 (>= 2.5)"
DISPLAY_NAME="QuickJS"
SHORT_DESC="Small JavaScript engine (ES2023), runtime for yt-dlp"
LONG_DESC="QuickJS $DEBVER built for Maemo 5 (armel, glibc 2.5): command qjs. Used by yt-dlp to solve the
JavaScript challenges of YouTube. Upstream: https://bellard.org/quickjs/"
debpack_build
