#!/bin/bash
# Package the built sfeed as a .deb for Maemo 5. Run INSIDE the Workshop after build.sh: make -C apps/sfeed deb
# Output: /project/build/deb/sfeed_<VERSION>-<REV>_armel.deb
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=sfeed
VERSION="${VERSION:-2.4}"
OUT="$PROJ/build/out/$PKG-$VERSION"
SRC="$PROJ/build/src/$PKG-$VERSION"
STAGE="$PROJ/build/deb/stage-$PKG"
[ -x "$OUT/root/opt/sfeed/bin/sfeed" ] || { echo "Missing build output in $OUT, run build.sh first (make build)"; exit 1; }

rm -rf "$STAGE"
mkdir -p "$STAGE/opt" "$STAGE/usr/bin" "$STAGE/opt/$PKG/share/doc/$PKG"
cp -a "$OUT/root/opt/sfeed" "$STAGE/opt/"
install -m 755 "$PROJ/apps/sfeed/sfeed-reader" "$STAGE/opt/$PKG/bin/sfeed-reader"
install -m 644 "$PROJ/apps/sfeed/sfeedrc.example" "$STAGE/opt/$PKG/share/doc/$PKG/sfeedrc.example"
install -m 644 "$SRC/LICENSE" "$STAGE/opt/$PKG/share/doc/$PKG/LICENSE"
# Links for the commands that people type.
for c in sfeed sfeed_plain sfeed_curses sfeed_update sfeed_markread sfeed_opml_import sfeed_opml_export sfeed-reader; do
    ln -s "../../opt/$PKG/bin/$c" "$STAGE/usr/bin/$c"
done
cat > "$STAGE/opt/$PKG/share/doc/$PKG/README.Maemo" <<EOT
sfeed $VERSION built for Maemo 5 (armel, glibc 2.5). Upstream: https://codemadness.org/sfeed-simple-feed-parser.html
Run: sfeed-reader (updates the feeds and opens the reader). Configuration: ~/.sfeed/sfeedrc (example in this directory).
Feeds are downloaded with curl (package curl), parsing and reading are done by the sfeed tools.
EOT
debpack_desktop "Feeds" "/usr/bin/sfeed-reader" "$PROJ/apps/sfeed/icon.png"

SECTION=user/network
DEPENDS="libc6 (>= 2.5), libncurses5 (>= 5.7), curl"
DISPLAY_NAME="sfeed"
SHORT_DESC="sfeed $VERSION RSS/Atom feed and podcast reader for the terminal"
LONG_DESC="sfeed $VERSION for Maemo 5: small tools that parse RSS/Atom feeds into a plain format and a curses reader.
Feeds are fetched with curl over TLS 1.3. Run sfeed-reader. Podcasts are normal feeds, the audio link is in the enclosure field."
debpack_build
