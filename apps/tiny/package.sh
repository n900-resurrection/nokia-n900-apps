#!/bin/bash
# Package TINY as a .deb for Maemo 5. Run INSIDE the Workshop after build.sh:
#   make -C apps/tiny deb
# Output: /project/build/deb/tiny_<VERSION>-<REV>_armel.deb
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=tiny
VERSION="${VERSION:-2.1}"
OUT="$PROJ/build/out/$PKG-$VERSION"
SRC="${TINY_SRC:-$PROJ/build/upstream/tiny}"
HERE="$PROJ/apps/tiny"
STAGE="$PROJ/build/deb/stage-$PKG"
[ -x "$OUT/tiny-bin" ] || { echo "Missing $OUT/tiny-bin, run build.sh first (make build)"; exit 1; }

rm -rf "$STAGE"
mkdir -p "$STAGE/opt/$PKG/bin" "$STAGE/opt/$PKG/share/$PKG" "$STAGE/opt/$PKG/share/doc/$PKG" "$STAGE/usr/bin"
install -m 755 "$OUT/tiny-bin" "$STAGE/opt/$PKG/bin/tiny-bin"
install -m 644 "$OUT/TINY.BIN" "$STAGE/opt/$PKG/share/$PKG/TINY.BIN"
# the launcher: the terminal of the phone says xterm, and the neon colours need 256
cat > "$STAGE/opt/$PKG/bin/tiny" <<'EOT'
#!/bin/sh
# TINY: a quiz robot (a neural network with 367,000 weights). Keys: PgUp / PgDn volume, Ctrl-A help. See man tiny.
case "$TERM" in xterm|"") TERM=xterm-256color; export TERM ;; esac
exec /opt/tiny/bin/tiny-bin "$@"
EOT
chmod 755 "$STAGE/opt/$PKG/bin/tiny"
ln -s ../../opt/$PKG/bin/tiny "$STAGE/usr/bin/tiny"
install -m 644 "$SRC/README.md" "$STAGE/opt/$PKG/share/doc/$PKG/README.md"
install -m 644 "$SRC/README.TXT" "$STAGE/opt/$PKG/share/doc/$PKG/README.TXT"
install -m 644 "$SRC/README.n900.md" "$STAGE/opt/$PKG/share/doc/$PKG/README.n900.md"
printf 'TINY 2.1 by its author (https://github.com/WollyMonjac/Tiny-2.1), "written by Fable 5.2 and trained by Opus 5.5".\nThe original has no licence file yet; the author has been asked in an issue of that repository. This is a test build.\nThe port to POSIX/ncurses (conio_ncurses.c, the layout, the sound) is in https://github.com/n900-resurrection/Tiny-2.1, branch n900.\n' > "$STAGE/opt/$PKG/share/doc/$PKG/NOTICE"
debpack_man "$HERE/tiny.1"
# a menu entry: the terminal of the phone starts the program
debpack_desktop "TINY" "/usr/bin/tiny" "$HERE/icon.png"

SECTION=user/games
# paplay plays the voice; the neon colours need the terminfo entry xterm-256color
DEPENDS="libc6 (>= 2.5), pulseaudio-utils, terminfo-256color"
DISPLAY_NAME="TINY"
SHORT_DESC="A quiz robot: a tiny neural network with a robot voice"
LONG_DESC="TINY 2.1 is a question answering neural network with 367,000 weights that reads and writes letter by letter and knows about 3,500 facts (countries, elements, animals, sums, words in other languages). Outside them it makes answers up. It has a full-screen terminal interface with a live neural monitor and a robot voice. Port of the DOS program to the N900: the screen follows the size of the terminal.
Keys: PgUp / PgDn volume, Ctrl-A help, Ctrl-S sound, Ctrl-V voice, Ctrl-T creativity, Esc quit.
Upstream: https://github.com/WollyMonjac/Tiny-2.1 (port: https://github.com/n900-resurrection/Tiny-2.1)"
debpack_build
