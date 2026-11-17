#!/bin/bash
# Package the built Brainfuck interpreter as a .deb for Maemo 5. Run INSIDE the Workshop after build.sh:
#   workshop exec n900 -- bash -c '/project/apps/bf-interpreter/package.sh'   (or: make -C apps/bf-interpreter deb)
# Output: /project/build/deb/bf-interpreter_<VERSION>-<REV>_armel.deb
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=bf-interpreter
VERSION="${VERSION:-0.1}"
OUT="$PROJ/build/out/$PKG-$VERSION"
SRC="$PROJ/build/upstream/$PKG"
STAGE="$PROJ/build/deb/stage-$PKG"
[ -x "$OUT/bf" ] || { echo "Missing $OUT/bf, run build.sh first (make build)"; exit 1; }

rm -rf "$STAGE"
mkdir -p "$STAGE/opt/$PKG/share/man/man1" "$STAGE/opt/$PKG/bin" "$STAGE/opt/$PKG/share/doc/$PKG" "$STAGE/opt/$PKG/share/examples" "$STAGE/usr/bin"
install -m 755 "$OUT/bf" "$STAGE/opt/$PKG/bin/bf"
ln -s "../../opt/$PKG/bin/bf" "$STAGE/usr/bin/bf"
install -m 644 "$SRC/LICENSE" "$STAGE/opt/$PKG/share/doc/$PKG/LICENSE"
install -m 644 "$SRC/README.md" "$STAGE/opt/$PKG/share/doc/$PKG/README.md"
install -m 644 "$SRC/tests/hello_world.txt" "$STAGE/opt/$PKG/share/examples/hello_world.bf"
gzip -9n -c "$PROJ/apps/bf-interpreter/bf.1" > "$STAGE/opt/$PKG/share/man/man1/bf.1.gz"
# a console tool that needs a file argument: no menu entry, but the icon of the Application Manager list
DEBPACK_ICON="$PROJ/apps/bf-interpreter/icon.png"

SECTION=user/development
DEPENDS="libc6 (>= 2.5)"
DISPLAY_NAME="BF interpreter"
SHORT_DESC="Brainfuck interpreter"
LONG_DESC="A small Brainfuck interpreter written in C (command: bf file.bf). The tape grows when the program needs it.
An example is in /opt/bf-interpreter/share/examples/hello_world.bf.
Built for Maemo 5 (armel, glibc 2.5). Upstream and author: https://github.com/elPytel/BF_interpreter (MIT)"
debpack_build
