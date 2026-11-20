#!/bin/bash
# Package the built Stockfish as a .deb for Maemo 5. Run INSIDE the Workshop after build.sh: make -C apps/stockfish deb
# Output: /project/build/deb/stockfish_<VERSION>-<REV>_armel.deb   (a command line engine: no menu entry)
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=stockfish
VERSION="${VERSION:-11}"
OUT="$PROJ/build/out/$PKG-$VERSION"
STAGE="$PROJ/build/deb/stage-$PKG"
[ -x "$OUT/stockfish" ] || { echo "Missing build output in $OUT, run build.sh first (make build)"; exit 1; }

rm -rf "$STAGE"; mkdir -p "$STAGE/opt/$PKG/bin" "$STAGE/opt/$PKG/share/doc/$PKG" "$STAGE/usr/bin"
install -m 755 "$OUT/stockfish" "$STAGE/opt/$PKG/bin/stockfish"
ln -s "../../opt/$PKG/bin/stockfish" "$STAGE/usr/bin/stockfish"
install -m 644 "$OUT/Copying.txt" "$STAGE/opt/$PKG/share/doc/$PKG/Copying.txt"
install -m 644 "$OUT/AUTHORS" "$STAGE/opt/$PKG/share/doc/$PKG/AUTHORS"
cat > "$STAGE/opt/$PKG/share/doc/$PKG/README.Maemo" <<EOT
Stockfish $VERSION (https://github.com/official-stockfish/Stockfish, tag sf_$VERSION, GPL-3.0-or-later) built for Maemo 5 by apps/stockfish of the
N900 project, unchanged, as a static musl binary. The source is the upstream tag; the recipe is apps/stockfish/build.sh.
Why version 11: later versions need a neural network file (about 40 MB) and are slower on a 600 MHz processor without a fast NEON path;
version 11 evaluates classically and reaches about 30 000 nodes per second here (depth 12 from the starting position in 3 seconds).
It is a UCI engine: it talks over stdin and stdout, so use it from a chess program, e.g. chess-tui (it finds /usr/bin/stockfish by itself).
Defaults to one thread and a 16 MB hash: the phone has little memory ("setoption name Hash value N").
EOT
SECTION=user/games
DEPENDS="libc6"
DISPLAY_NAME="Stockfish"
SHORT_DESC="Stockfish $VERSION chess engine (UCI)"
LONG_DESC="Stockfish $VERSION, a strong open source chess engine with the classical evaluation (no neural network file). It speaks UCI on stdin
and stdout, so a chess program uses it as the opponent; chess-tui does it with -e /usr/bin/stockfish. About 30 000 nodes per second on the N900:
depth 12 in 3 seconds. Built for Maemo 5 as a static binary, 1.1 MB.
Upstream: https://github.com/official-stockfish/Stockfish"
MAINTAINER="elPytel (build of upstream Stockfish by the Stockfish developers)"
debpack_build
