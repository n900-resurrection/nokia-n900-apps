#!/bin/bash
# Package the built fd as a .deb for Maemo 5. Run INSIDE the Workshop after build.sh: make -C apps/fd deb
# Output: /project/build/deb/fd_<VERSION>-<REV>_armel.deb   (a command line tool: no menu entry)
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=fd
VERSION="${VERSION:-10.5.2}"
OUT="$PROJ/build/out/fd-find-$VERSION"
STAGE="$PROJ/build/deb/stage-$PKG"
[ -x "$OUT/fd" ] || { echo "Missing build output in $OUT, run build.sh first (make build)"; exit 1; }

rm -rf "$STAGE"; mkdir -p "$STAGE/opt/fd/bin" "$STAGE/opt/fd/share/doc/fd" "$STAGE/usr/bin"
install -m 755 "$OUT/fd" "$STAGE/opt/fd/bin/fd"
ln -s "../../opt/fd/bin/fd" "$STAGE/usr/bin/fd"
for f in "$PROJ"/build/rust/cargo/registry/src/*/fd-find-$VERSION/{LICENSE-MIT,LICENSE-APACHE}; do
    [ -f "$f" ] && install -m 644 "$f" "$STAGE/opt/fd/share/doc/fd/"
done

SECTION=user/utilities
DEPENDS="libc6"
DISPLAY_NAME="fd"
SHORT_DESC="fd $VERSION simple, fast alternative to find"
LONG_DESC="fd $VERSION: finds files by name with a regular expression, coloured output, respects .gitignore, skips hidden files and runs commands on the
results (fd -e png -x ls -l). Example: fd report ~/MyDocs   or   fd -e deb. Built for Maemo 5 with Rust as a static binary.
Upstream: https://github.com/sharkdp/fd"
MAINTAINER="elPytel (build of upstream fd by David Peter and contributors)"
debpack_build
