#!/bin/bash
# Package the built micro as a .deb for Maemo 5. Run INSIDE the Workshop after build.sh: make -C apps/micro deb
# Output: /project/build/deb/micro_<VERSION>-<REV>_armel.deb   (menu entry "Micro" starts it in the terminal)
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=micro
VERSION="${VERSION:-2.0.15}"
OUT="$PROJ/build/out/$PKG-$VERSION"
STAGE="$PROJ/build/deb/stage-$PKG"
[ -x "$OUT/micro" ] || { echo "Missing build output in $OUT, run build.sh first (make build)"; exit 1; }

rm -rf "$STAGE"; mkdir -p "$STAGE/opt/micro/bin" "$STAGE/opt/micro/share/doc/micro" "$STAGE/usr/bin"
install -m 755 "$OUT/micro" "$STAGE/opt/micro/bin/micro"
ln -s "../../opt/micro/bin/micro" "$STAGE/usr/bin/micro"
install -m 644 "$OUT/LICENSE" "$STAGE/opt/micro/share/doc/micro/LICENSE"
debpack_desktop "Micro" "/usr/bin/micro" "$PROJ/apps/micro/icon.png"

SECTION=user/text
DEPENDS="libc6"
DISPLAY_NAME="Micro"
SHORT_DESC="micro $VERSION terminal text editor with normal keys"
LONG_DESC="micro $VERSION: a small editor for the terminal that works the way most people expect: Ctrl-S saves, Ctrl-Q quits, Ctrl-C/X/V copy, cut and
paste, Ctrl-F searches, Ctrl-E opens a command line (help, set, plugin), the mouse works. Syntax highlighting for many languages. An easier alternative to vim
and nano on the N900 (the Q key and the arrows are on the keyboard). Built for Maemo 5 with Go (static). Upstream: https://micro-editor.github.io"
MAINTAINER="elPytel (build of upstream micro by Zachary Yedidia and contributors)"
debpack_build
