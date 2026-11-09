#!/bin/bash
# Compile terminfo entries in the legacy format that ncurses 5.7 of Maemo reads (magic 0x011a).
#   make -C apps/terminfo-256color build     (runs inside the Workshop; needs tic/infocmp of the host ncurses)
# The 256-colour entries of ncurses 6 say pairs#65536, which does not fit the legacy format: we lower it to 32767 (screen and tmux; xterm comes from the .src file).
set -euo pipefail
OUT=/project/build/terminfo-256color
rm -rf "$OUT"; mkdir -p "$OUT"
# xterm-256color is built on the stock xterm entry of the phone (xterm-256color.src: colours 256, the rest unchanged). The modern ncurses entry
# draws line characters with ESC ( 0, which the terminal of Maemo does not understand (broken frames in dialog); the stock entry uses SO/SI (smacs=^N, rmacs=^O).
HERE=$(cd "$(dirname "$0")" && pwd)
tic -o "$OUT" "$HERE/xterm-256color.src"
for t in screen-256color tmux-256color; do
    infocmp -1 "$t" | sed -E 's/pairs#(0x[0-9a-f]+|[0-9]+)/pairs#32767/' | tic -o "$OUT" -
done
for f in $(find "$OUT" -type f); do
    [ "$(od -An -tx1 -N2 "$f" | tr -d ' ')" = 1a01 ] || { echo "not the legacy format: $f" >&2; exit 1; }
done
find "$OUT" -type f | sort
