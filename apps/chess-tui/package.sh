#!/bin/bash
# Package the built chess-tui (static musl binary) as a .deb for Maemo 5. Run INSIDE the Workshop after build.sh: make -C apps/chess-tui deb
# Output: /project/build/deb/chess-tui_<VERSION>-<REV>_armel.deb
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=chess-tui
VERSION="${VERSION:-2.8.1}"
OUT="$PROJ/build/out/$PKG-$VERSION"
SRC=$(ls -d "$PROJ"/build/rust/cargo/registry/src/*/chess-tui-$VERSION | head -1)
STAGE="$PROJ/build/deb/stage-$PKG"
[ -x "$OUT/chess-tui" ] || { echo "Missing build output in $OUT, run build.sh first (make build)"; exit 1; }

rm -rf "$STAGE"
mkdir -p "$STAGE/opt/$PKG/bin" "$STAGE/opt/$PKG/share/doc/$PKG" "$STAGE/usr/bin"
install -m 755 "$OUT/chess-tui" "$STAGE/opt/$PKG/bin/chess-tui"
# /usr/bin/chess-tui: a wrapper that uses the engine of the package stockfish when there is one and no engine was given
cat > "$STAGE/usr/bin/chess-tui" <<'EOW'
#!/bin/sh
case " $* " in
    *" -e "*|*" --engine-path"*) ;;
    *) [ -x /usr/bin/stockfish ] && set -- -e /usr/bin/stockfish "$@" ;;
esac
exec /opt/chess-tui/bin/chess-tui "$@"
EOW
chmod 755 "$STAGE/usr/bin/chess-tui"
install -m 644 "$SRC/LICENSE" "$STAGE/opt/$PKG/share/doc/$PKG/LICENSE"
cat > "$STAGE/opt/$PKG/share/doc/$PKG/README.Maemo" <<EOT
chess-tui $VERSION (https://github.com/thomas-mauran/chess-tui, MIT) built for Maemo 5 by apps/chess-tui of the N900 project: Rust, static musl
binary, no dependencies, built without the "sound" feature (the --no-sound option has no effect). The build recipe is apps/chess-tui/build.sh.
Play against a person on the same phone, or against a UCI engine: give it with -e /path/to/engine (the package stockfish is found by itself: /usr/bin/stockfish), or play online on Lichess with a token (-l TOKEN or in the configuration).
Configuration: ~/.config/chess-tui/ (created on the first start).
EOT
debpack_desktop "Chess" "/usr/bin/chess-tui" "$PROJ/apps/chess-tui/icon.png"

SECTION=user/games
DEPENDS="libc6"
DISPLAY_NAME="Chess (chess-tui)"
SHORT_DESC="chess-tui $VERSION chess for the terminal"
LONG_DESC="chess-tui $VERSION: a chess game for the terminal (a board drawn with characters, skins, a viewer of PGN files). Two players on one phone,
a UCI engine as the opponent (the package stockfish is used when it is installed; else chess-tui -e /path/to/engine) or Lichess online with a token. Built for Maemo 5 with Rust as a static
binary, 5 MB; it needs no libraries. The menu entry opens it in the terminal.
Upstream: https://github.com/thomas-mauran/chess-tui"
MAINTAINER="elPytel (build of upstream chess-tui by Thomas Mauran and contributors)"
debpack_build
