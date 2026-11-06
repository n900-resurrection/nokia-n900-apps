#!/bin/bash
# Package ranger as a .deb for Maemo 5. Run INSIDE the Workshop after build.sh: make -C apps/ranger deb
# Output: /project/build/deb/ranger_<VERSION>-<REV>_armel.deb
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=ranger
VERSION="${VERSION:-1.9.4}"
OUT="$PROJ/build/out/$PKG-$VERSION"
STAGE="$PROJ/build/deb/stage-$PKG"
[ -d "$OUT/root/opt/ranger" ] || { echo "Missing build output in $OUT, run build.sh first (make build)"; exit 1; }

rm -rf "$STAGE"; mkdir -p "$STAGE"
cp -a "$OUT/root/." "$STAGE/"
debpack_desktop "Ranger" "/usr/bin/ranger"

SECTION=user/utilities
DEPENDS="python3.11"
DISPLAY_NAME="Ranger"
SHORT_DESC="ranger $VERSION console file manager"
LONG_DESC="ranger $VERSION, a console file manager with VI key bindings, for Maemo 5. It runs on the Python 3.11 of the package python3.11.
Run ranger in the terminal (arrow keys or h j k l, q quits). Opening files uses vim and mplayer of the phone; the previews of files need the tool file, which the phone does not have, so only directories and plain text are previewed.
Upstream: https://ranger.fm/"
MAINTAINER="elPytel (build of upstream ranger by Roman Zimbelmann and contributors)"
debpack_build
