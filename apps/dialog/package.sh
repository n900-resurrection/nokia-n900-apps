#!/bin/bash
# Package the built dialog as a .deb for Maemo 5. Run INSIDE the Workshop after build.sh: make -C apps/dialog deb
# Output: /project/build/deb/dialog_<VERSION>-<REV>_armel.deb   (a command line tool: no menu entry)
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=dialog
VERSION="${VERSION:-1.3-20260721}"
OUT="$PROJ/build/out/$PKG-$VERSION"
STAGE="$PROJ/build/deb/stage-$PKG"
[ -x "$OUT/root/opt/dialog/bin/dialog" ] || { echo "Missing build output in $OUT, run build.sh first (make build)"; exit 1; }

rm -rf "$STAGE"; mkdir -p "$STAGE/usr/bin" "$STAGE/opt/dialog/share/doc/dialog"
cp -a "$OUT/root/." "$STAGE/"
ln -s "../../opt/dialog/bin/dialog" "$STAGE/usr/bin/dialog"
install -m 644 "$OUT/COPYING" "$STAGE/opt/dialog/share/doc/dialog/COPYING"

SECTION=user/development
DEPENDS="libc6 (>= 2.5)"
DISPLAY_NAME="dialog"
SHORT_DESC="dialog $VERSION: dialog boxes for shell scripts"
LONG_DESC="dialog $VERSION: text-mode menus, check lists, input boxes, message boxes, file selectors and gauges for shell scripts (dialog --menu, --checklist, --msgbox, --inputbox, --yesno). Full options: dialog --help. Built for Maemo 5 with a static ncursesw (UTF-8, line drawing).
Upstream: https://invisible-island.net/dialog/"
MAINTAINER="elPytel (build of upstream dialog by Thomas E. Dickey)"
debpack_build
