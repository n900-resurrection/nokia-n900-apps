#!/bin/bash
# Package the built rsync as a .deb for Maemo 5. Run INSIDE the Workshop after build.sh: make -C apps/rsync deb
# Output: /project/build/deb/rsync_<VERSION>-<REV>_armel.deb   (a command line tool: no menu entry)
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=rsync
VERSION="${VERSION:-3.5.2}"
OUT="$PROJ/build/out/$PKG-$VERSION"
STAGE="$PROJ/build/deb/stage-$PKG"
[ -x "$OUT/root/opt/rsync/bin/rsync" ] || { echo "Missing build output in $OUT, run build.sh first (make build)"; exit 1; }

rm -rf "$STAGE"; mkdir -p "$STAGE/usr/bin"
cp -a "$OUT/root/." "$STAGE/"
ln -s "../../opt/rsync/bin/rsync" "$STAGE/usr/bin/rsync"
mkdir -p "$STAGE/opt/rsync/share/doc/rsync"
install -m 644 "$PROJ/build/src/rsync-$VERSION/COPYING" "$STAGE/opt/rsync/share/doc/rsync/COPYING"

SECTION=user/network
DEPENDS="libc6 (>= 2.5)"
DISPLAY_NAME="rsync"
SHORT_DESC="rsync $VERSION file synchronisation over SSH"
LONG_DESC="rsync $VERSION for Maemo 5: copies and synchronises files and directories, sending only the differences (rsync -avz --progress ~/dir user@host:backup/).
It uses the ssh of the phone as the transport (the same rsync must be on the other side). Built for armel, glibc 2.5, without the optional compression
and checksum libraries. Upstream: https://rsync.samba.org"
MAINTAINER="elPytel (build of upstream rsync by Andrew Tridgell, Wayne Davison and contributors)"
debpack_build
