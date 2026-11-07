#!/bin/bash
# Package the built strace as a .deb for Maemo 5. Run INSIDE the Workshop after build.sh: make -C apps/strace deb
# Output: /project/build/deb/strace_<VERSION>-<REV>_armel.deb   (a command line tool: no menu entry)
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=strace
VERSION="${VERSION:-6.19}"
OUT="$PROJ/build/out/$PKG-$VERSION"
STAGE="$PROJ/build/deb/stage-$PKG"
[ -x "$OUT/root/opt/strace/bin/strace" ] || { echo "Missing build output in $OUT, run build.sh first (make build)"; exit 1; }

rm -rf "$STAGE"; mkdir -p "$STAGE/usr/bin"
cp -a "$OUT/root/." "$STAGE/"
ln -s "../../opt/strace/bin/strace" "$STAGE/usr/bin/strace"
mkdir -p "$STAGE/opt/strace/share/doc/strace"
install -m 644 "$PROJ/build/src/strace-$VERSION/COPYING" "$STAGE/opt/strace/share/doc/strace/COPYING"

SECTION=user/utilities
DEPENDS="libc6 (>= 2.5)"
DISPLAY_NAME="strace"
SHORT_DESC="strace $VERSION system call tracer"
LONG_DESC="strace $VERSION for Maemo 5: shows the system calls and signals of a program (strace -f -o /tmp/out.txt command; strace -p PID).
Useful when an application hangs or fails without a message. Built for armel (native ABI only), glibc 2.5.
Upstream: https://strace.io"
MAINTAINER="elPytel (build of upstream strace by the strace project)"
debpack_build
