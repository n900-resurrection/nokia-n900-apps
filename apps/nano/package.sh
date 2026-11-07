#!/bin/bash
# Package the built nano as a .deb for Maemo 5. Run INSIDE the Workshop after build.sh: make -C apps/nano deb
# Output: /project/build/deb/nano_<VERSION>-<REV>_armel.deb
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=nano
VERSION="${VERSION:-9.3}"
OUT="$PROJ/build/out/$PKG-$VERSION"
STAGE="$PROJ/build/deb/stage-$PKG"
[ -x "$OUT/root/opt/nano/bin/nano" ] || { echo "Missing build output in $OUT, run build.sh first (make build)"; exit 1; }

rm -rf "$STAGE"
mkdir -p "$STAGE/opt" "$STAGE/usr/bin" "$STAGE/opt/$PKG/etc"
cp -a "$OUT/root/opt/nano" "$STAGE/opt/"
install -m 644 "$PROJ/apps/nano/nanorc" "$STAGE/opt/$PKG/etc/nanorc"
ln -s "../../opt/$PKG/bin/nano" "$STAGE/usr/bin/nano"
ln -s "../../opt/$PKG/bin/rnano" "$STAGE/usr/bin/rnano"
debpack_desktop "Nano" "/usr/bin/nano" "$PROJ/apps/nano/icon.png"

SECTION=user/utilities
# Linked statically against ncursesw, so only libc is needed.
DEPENDS="libc6 (>= 2.5)"
DISPLAY_NAME="nano"
SHORT_DESC="GNU nano $VERSION text editor for the terminal"
LONG_DESC="GNU nano $VERSION for Maemo 5: an easy console editor with on-screen shortcuts (^O save, ^X quit, ^G help).
UTF-8 text, syntax highlighting (/opt/nano/etc/nanorc) and the man page/info in /opt/nano/share. Built for armel, glibc 2.5.
Upstream: https://www.nano-editor.org"
debpack_build
