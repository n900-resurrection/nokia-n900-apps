#!/bin/bash
# Package the built tig as a .deb for Maemo 5. Run INSIDE the Workshop after build.sh: make -C apps/tig deb
# Output: /project/build/deb/tig_<VERSION>-<REV>_armel.deb   (a command line tool: no menu entry)
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=tig
VERSION="${VERSION:-2.6.1}"
OUT="$PROJ/build/out/$PKG-$VERSION"
STAGE="$PROJ/build/deb/stage-$PKG"
[ -x "$OUT/root/opt/tig/bin/tig" ] || { echo "Missing build output in $OUT, run build.sh first (make build)"; exit 1; }

rm -rf "$STAGE"; mkdir -p "$STAGE/usr/bin" "$STAGE/opt/tig/share/doc/tig"
cp -a "$OUT/root/." "$STAGE/"
ln -s "../../opt/tig/bin/tig" "$STAGE/usr/bin/tig"
install -m 644 "$OUT/COPYING" "$STAGE/opt/tig/share/doc/tig/COPYING"

SECTION=user/development
DEPENDS="libc6 (>= 2.5), git"
DISPLAY_NAME="tig"
SHORT_DESC="tig $VERSION text-mode interface for git"
LONG_DESC="tig $VERSION: browse the history of a git repository, diffs, files and branches, stage changes line by line. Run it in a repository (tig, tig status,
tig blame file, tig show). Keys: Enter opens, q closes, h shows the help. It uses the git of this repository's git package (modern git with HTTPS).
Built for Maemo 5 with a static ncursesw (UTF-8). Upstream: https://jonas.github.io/tig"
MAINTAINER="elPytel (build of upstream tig by Jonas Fonseca and contributors)"
debpack_build
