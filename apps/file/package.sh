#!/bin/bash
# Package the built file(1) + libmagic database as a .deb for Maemo 5. Run INSIDE the Workshop after build.sh: make -C apps/file deb
# Output: /project/build/deb/file_<VERSION>-<REV>_armel.deb   (a command line tool: no menu entry)
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=file
VERSION="${VERSION:-5.48}"
OUT="$PROJ/build/out/$PKG-$VERSION"
STAGE="$PROJ/build/deb/stage-$PKG"
[ -x "$OUT/root/opt/file/bin/file" ] || { echo "Missing build output in $OUT, run build.sh first (make build)"; exit 1; }

rm -rf "$STAGE"; mkdir -p "$STAGE/usr/bin"
cp -a "$OUT/root/." "$STAGE/"
rm -rf "$STAGE/opt/file/include" "$STAGE/opt/file/lib" "$STAGE/opt/file/share/man/man3"
ln -s "../../opt/file/bin/file" "$STAGE/usr/bin/file"
mkdir -p "$STAGE/opt/file/share/doc/file"
install -m 644 "$PROJ/build/src/file-$VERSION/COPYING" "$STAGE/opt/file/share/doc/file/COPYING"

SECTION=user/utilities
DEPENDS="libc6 (>= 2.5)"
DISPLAY_NAME="file"
SHORT_DESC="file $VERSION file type detection"
LONG_DESC="file $VERSION for Maemo 5: tells the type of a file from its content (file -b --mime-type photo.jpg). The magic database is in /opt/file/share/misc/magic.mgc.
The file manager ranger uses it for files with an unknown extension (the package ranger has only a small stand-in: this one takes precedence in /usr/bin).
Compressed files are not looked into (no zlib/bzip2/xz in this build). Upstream: https://www.darwinsys.com/file/"
MAINTAINER="elPytel (build of upstream file by Christos Zoulas and contributors)"
debpack_build
