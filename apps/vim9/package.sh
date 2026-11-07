#!/bin/bash
# Package the built Vim 9 as a .deb for Maemo 5. Run INSIDE the Workshop after build.sh: make -C apps/vim9 deb
# Output: /project/build/deb/vim9_<VERSION>-<REV>_armel.deb   (package vim9: /opt/vim9, the command is vim9)
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=vim9
VERSION="${VERSION:-9.2.1302}"
OUT="$PROJ/build/out/$PKG-$VERSION"
STAGE="$PROJ/build/deb/stage-$PKG"
[ -x "$OUT/root/opt/vim9/bin/vim" ] || { echo "Missing build output in $OUT, run build.sh first (make build)"; exit 1; }

rm -rf "$STAGE"
mkdir -p "$STAGE/opt" "$STAGE/usr/bin"
cp -a "$OUT/root/opt/vim9" "$STAGE/opt/"
V="$STAGE/opt/vim9"
# smaller: no spell files, translated tutors and desktop files of the GUI, no man pages in other languages
rm -rf "$V/share/vim/vim92/spell" "$V/share/vim/vim92/tutor" "$V/share/applications" "$V/share/icons" "$V/share/man/"[a-z][a-z] "$V/share/man/"[a-z][a-z]_*
install -m 644 "$PROJ/apps/vim9/vimrc" "$V/share/vim/vimrc"
# The commands: vim9 (not vim: that is the vim 7.2 of the system, with vi and the alternatives), view9 and xxd9.
ln -s ../../opt/vim9/bin/vim "$STAGE/usr/bin/vim9"
ln -s ../../opt/vim9/bin/xxd "$STAGE/usr/bin/xxd9"
debpack_desktop "Vim 9" "/usr/bin/vim9" "$PROJ/apps/vim9/icon.png"

SECTION=user/utilities
DEPENDS="libc6 (>= 2.5), libncurses5 (>= 5.7)"
DISPLAY_NAME="Vim 9"
SHORT_DESC="Vim $VERSION text editor for the terminal (command vim9)"
LONG_DESC="Vim 9 for Maemo 5 next to the system vim 7.2: the command is vim9 (the system vim and vi stay untouched). Normal features,
UTF-8, syntax highlighting, no GUI and no scripting languages. The tool xxd is xxd9. Built for armel, glibc 2.5.
Settings: /opt/vim9/share/vim/vimrc (the mouse is off), personal ~/.vimrc. Upstream: https://www.vim.org"
debpack_build
