#!/bin/bash
# Package the built fzf as a .deb for Maemo 5. Run INSIDE the Workshop after build.sh: make -C apps/fzf deb
# Output: /project/build/deb/fzf_<VERSION>-<REV>_armel.deb   (a command line tool: no menu entry)
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=fzf
VERSION="${VERSION:-0.75.0}"
OUT="$PROJ/build/out/$PKG-$VERSION"
STAGE="$PROJ/build/deb/stage-$PKG"
[ -x "$OUT/fzf" ] || { echo "Missing build output in $OUT, run build.sh first (make build)"; exit 1; }

rm -rf "$STAGE"; mkdir -p "$STAGE/opt/fzf/bin" "$STAGE/opt/fzf/share/doc/fzf" "$STAGE/usr/bin"
install -m 755 "$OUT/fzf" "$STAGE/opt/fzf/bin/fzf"
ln -s "../../opt/fzf/bin/fzf" "$STAGE/usr/bin/fzf"
LIC=$(ls "$PROJ"/build/go/gopath/pkg/mod/github.com/junegunn/fzf@v$VERSION/LICENSE 2>/dev/null | head -1)
[ -n "$LIC" ] && install -m 644 "$LIC" "$STAGE/opt/fzf/share/doc/fzf/LICENSE"

SECTION=user/utilities
DEPENDS="libc6"
DISPLAY_NAME="fzf"
SHORT_DESC="fzf $VERSION fuzzy finder for the command line"
LONG_DESC="fzf $VERSION: an interactive filter for lists. Pipe anything into it (ls | fzf, history | fzf, find . -type f | fzf), type a few letters of the
line you want and press Enter. With bash 5 the key bindings come from: eval \"\$(fzf --bash)\" (Ctrl-R history, Ctrl-T files, Alt-C directories).
Built for Maemo 5 with Go (static, GOARM=7, the 2.6.28 kernel needs the patched toolchain of this project). Upstream: https://github.com/junegunn/fzf"
MAINTAINER="elPytel (build of upstream fzf by Junegunn Choi and contributors)"
debpack_build
