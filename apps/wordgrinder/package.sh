#!/bin/bash
# Package the built WordGrinder as a .deb for Maemo 5. Run INSIDE the Workshop after build.sh:
#   workshop exec n900 -- bash -c 'VERSION=0.8 REV=1maemo1 /project/apps/wordgrinder/package.sh'
#   (or on the host: make -C apps/wordgrinder deb)
# Output: /project/build/deb/wordgrinder_<VERSION>-<REV>_armel.deb
#
# Status: verified on a real N900 (2026-11-04): install, dpkg -L, ldd, launch from the menu.
# Not verified: installation through the Application Manager, see DOC/packaging.md, section 4.
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=wordgrinder
VERSION="${VERSION:-0.8}"
OUT="$PROJ/build/out/$PKG-$VERSION"
SRC="$PROJ/build/upstream/$PKG"
STAGE="$PROJ/build/deb/stage-$PKG"
[ -x "$OUT/$PKG" ] || { echo "Missing $OUT/$PKG, run build.sh first (make build)"; exit 1; }

rm -rf "$STAGE"
mkdir -p "$STAGE/opt/$PKG/bin" "$STAGE/opt/$PKG/share/doc/$PKG" "$STAGE/opt/$PKG/share/man/man1" "$STAGE/usr/bin"

# The application lives in /opt (a bind mount of /home/opt on the device; the root partition is small).
install -m 755 "$OUT/$PKG" "$STAGE/opt/$PKG/bin/$PKG"
install -m 644 "$SRC/README.wg" "$STAGE/opt/$PKG/share/doc/$PKG/README.wg"
if [ -d "$SRC/licenses" ]; then
    cp -r "$SRC/licenses" "$STAGE/opt/$PKG/share/doc/$PKG/licenses"
fi
gzip -9n -c "$SRC/wordgrinder.man" > "$STAGE/opt/$PKG/share/man/man1/$PKG.1.gz"

# Link in PATH (relative, so it works regardless of the root it is installed under)
ln -s "../../opt/$PKG/bin/$PKG" "$STAGE/usr/bin/$PKG"

# Menu launcher. A console application needs a terminal.
debpack_desktop "WordGrinder" "/usr/bin/$PKG" "$PROJ/build/upstream/wordgrinder/extras/icon.png"

SECTION=user/office
DEPENDS="libc6 (>= 2.5), zlib1g"
DISPLAY_NAME="WordGrinder"
SHORT_DESC="Console word processor"
LONG_DESC="WordGrinder is a simple, Unicode-aware word processor that runs on the console.
Built for Maemo 5 (armel, glibc 2.5) with ncursesw linked statically.
Upstream: https://github.com/davidgiven/wordgrinder"
debpack_build
