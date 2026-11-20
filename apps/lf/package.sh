#!/bin/bash
# Package the built lf as a .deb for Maemo 5. Run INSIDE the Workshop after build.sh: make -C apps/lf deb
# Output: /project/build/deb/lf_<VERSION>-<REV>_armel.deb   (the menu entry opens it in the terminal)
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=lf
VERSION="${VERSION:-41}"
OUT="$PROJ/build/out/$PKG-r$VERSION"
# the module cache names a tag that is not semver (r41) by a pseudo version: the newest directory that has the matching manual page is the one built
SRC=$(ls -dt "$PROJ"/build/go/gopath/pkg/mod/github.com/gokcehan/lf@* | head -1)
[ -f "$SRC/lf.1" ] || { echo "no lf sources in the module cache"; exit 1; }
STAGE="$PROJ/build/deb/stage-$PKG"
[ -x "$OUT/lf" ] || { echo "Missing build output in $OUT, run build.sh first (make build)"; exit 1; }

rm -rf "$STAGE"; mkdir -p "$STAGE/opt/lf/bin" "$STAGE/opt/lf/share/doc/lf" "$STAGE/usr/bin"
install -m 755 "$OUT/lf" "$STAGE/opt/lf/bin/lf"
ln -s "../../opt/lf/bin/lf" "$STAGE/usr/bin/lf"
install -m 644 "$SRC/LICENSE" "$STAGE/opt/lf/share/doc/lf/LICENSE"
install -m 644 "$SRC/doc.md" "$STAGE/opt/lf/share/doc/lf/doc.md"
install -m 644 "$SRC/etc/lfrc.example" "$STAGE/opt/lf/share/doc/lf/lfrc.example"
debpack_desktop "File manager (lf)" "/usr/bin/lf" "$PROJ/apps/lf/icon.png"

SECTION=user/utilities
DEPENDS="libc6"
DISPLAY_NAME="lf (file manager)"
SHORT_DESC="lf r$VERSION terminal file manager"
LONG_DESC="lf r$VERSION (list files): a file manager for the terminal in the style of ranger, written in Go. Three columns (parent, current, preview),
vi-like keys (h j k l, / search, space select, y d p copy, move and paste, a Enter opens), a preview of text files and your own commands through
the configuration file ~/.config/lf/lfrc (an example is in /opt/lf/share/doc/lf/lfrc.example). Built for Maemo 5 as a static binary (about 3 MB).
Upstream: https://github.com/gokcehan/lf"
MAINTAINER="elPytel (build of upstream lf by Gokcehan Kara and contributors)"
# the manual page is in the sources
debpack_man "$SRC/lf.1"
debpack_build
