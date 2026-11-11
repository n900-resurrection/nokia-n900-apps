#!/bin/bash
# Package the built xmllint and xsltproc as a .deb for Maemo 5. Run INSIDE the Workshop after build.sh: make -C apps/xml-tools deb
# Output: /project/build/deb/xml-tools_<VERSION>-<REV>_armel.deb
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=xml-tools
VERSION="${VERSION:-2.15.4}"
XSLT_VERSION="${XSLT_VERSION:-1.1.45}"
OUT="$PROJ/build/out/$PKG-$VERSION"
STAGE="$PROJ/build/deb/stage-$PKG"
[ -x "$OUT/xmllint" ] || { echo "Missing $OUT/xmllint, run build.sh first (make build)"; exit 1; }

rm -rf "$STAGE"
mkdir -p "$STAGE/opt/$PKG/bin" "$STAGE/opt/$PKG/share/doc/$PKG" "$STAGE/usr/bin"
for b in xmllint xsltproc; do
    install -m 755 "$OUT/$b" "$STAGE/opt/$PKG/bin/$b"
    ln -s "../../opt/$PKG/bin/$b" "$STAGE/usr/bin/$b"
done
install -m 644 "$PROJ/build/src/libxml2-$VERSION/Copyright" "$STAGE/opt/$PKG/share/doc/$PKG/COPYING.libxml2"
install -m 644 "$PROJ/build/src/libxslt-$XSLT_VERSION/Copyright" "$STAGE/opt/$PKG/share/doc/$PKG/COPYING.libxslt"

SECTION=user/utilities
DEPENDS="libc6 (>= 2.5)"
DISPLAY_NAME="XML tools"
SHORT_DESC="xmllint and xsltproc (libxml2 $VERSION, libxslt $XSLT_VERSION)"
LONG_DESC="Command-line XML tools built for Maemo 5 (armel, glibc 2.5), statically linked:
xmllint (well-formedness, XPath, pretty-printing, schema validation) and xsltproc (XSLT 1.0 with EXSLT).
The system libxml2 2.6.32 stays untouched.
Upstream: https://gitlab.gnome.org/GNOME/libxml2"
debpack_build
