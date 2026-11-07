#!/bin/bash
# Package the built whiptail as a .deb for Maemo 5. Run INSIDE the Workshop after build.sh: make -C apps/whiptail deb
# Output: /project/build/deb/whiptail_<VERSION>-<REV>_armel.deb   (a command line tool: no menu entry)
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=whiptail
VERSION="${VERSION:-0.52.25}"
OUT="$PROJ/build/out/$PKG-$VERSION"
STAGE="$PROJ/build/deb/stage-$PKG"
[ -x "$OUT/root/opt/whiptail/bin/whiptail" ] || { echo "Missing build output in $OUT, run build.sh first (make build)"; exit 1; }

rm -rf "$STAGE"; mkdir -p "$STAGE/usr/bin" "$STAGE/opt/whiptail/share/doc/whiptail"
cp -a "$OUT/root/." "$STAGE/"
ln -s "../../opt/whiptail/bin/whiptail" "$STAGE/usr/bin/whiptail"
install -m 644 "$OUT/COPYING" "$STAGE/opt/whiptail/share/doc/whiptail/COPYING"

SECTION=user/development
DEPENDS="libc6 (>= 2.5)"
DISPLAY_NAME="whiptail"
SHORT_DESC="whiptail (newt $VERSION): dialog boxes for shell scripts"
LONG_DESC="whiptail from newt $VERSION: text-mode menus, check lists, input boxes, message boxes and gauges for shell scripts (whiptail --menu, --checklist, --msgbox, --inputbox, --yesno), compatible with the common dialog options. Small: slang and popt are linked statically.
Upstream: https://pagure.io/newt"
MAINTAINER="elPytel (build of upstream newt by Red Hat and contributors)"
debpack_build
