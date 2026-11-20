#!/bin/bash
# Package the built GNU less as a .deb for Maemo 5. Run INSIDE the Workshop after build.sh: make -C apps/less deb
# Output: /project/build/deb/less_<VERSION>-<REV>_armel.deb   (a command line tool: no menu entry; it is not linked into /usr/bin, see the description)
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=less
VERSION="${VERSION:-710}"
OUT="$PROJ/build/out/$PKG-$VERSION"
SRC="$PROJ/build/src/less-$VERSION"
STAGE="$PROJ/build/deb/stage-$PKG"
[ -x "$OUT/root/opt/less/bin/less" ] || { echo "Missing build output in $OUT, run build.sh first (make build)"; exit 1; }

rm -rf "$STAGE"; mkdir -p "$STAGE/opt"
cp -a "$OUT/root/opt/less" "$STAGE/opt/"
mkdir -p "$STAGE/opt/less/share/doc/less"
install -m 644 "$SRC/COPYING" "$SRC/LICENSE" "$SRC/NEWS" "$STAGE/opt/less/share/doc/less/"

SECTION=user/utilities
DEPENDS="libc6 (>= 2.4)"
DISPLAY_NAME="less"
SHORT_DESC="GNU less $VERSION pager"
LONG_DESC="GNU less $VERSION for Maemo 5: the pager of the phone is the small one of BusyBox, which has no --version, no marks and no incremental search.
This less lives in /opt/less/bin/less and does not replace the system pager; programs that want it (offpunk does) put /opt/less/bin first in PATH,
and you can do it in your shell: export PATH=/opt/less/bin:\$PATH. UTF-8 text, ANSI colours with -R, search with / and ?, q quits.
Upstream: https://www.greenwoodsoftware.com/less/"
MAINTAINER="elPytel (build of upstream less by Mark Nudelman)"
debpack_man "$OUT/root/opt/less/share/man/man1/less.1"
debpack_build
