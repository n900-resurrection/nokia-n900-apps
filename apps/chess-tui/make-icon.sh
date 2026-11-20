#!/bin/bash
# Draw the menu icon of chess-tui -> icon.png next to this script (see scripts/icon-lib.sh).
set -euo pipefail
D="$(cd "$(dirname "$0")" && pwd)"
. "$D/../../scripts/icon-lib.sh"

# a 4x4 piece of a chess board (brown and cream), a white pawn on it, and the prompt of a terminal
args=()
for r in 0 1 2 3; do for c in 0 1 2 3; do
    if [ $(( (r + c) % 2 )) -eq 0 ]; then col='#f0d9b5'; else col='#b58863'; fi
    args+=(-fill "$col" -draw "rectangle $((32 + c * 48)),$((24 + r * 48)) $((79 + c * 48)),$((71 + r * 48))")
done; done
icon_base "${args[@]}" \
    -fill '#fafafa' -stroke '#222222' -strokewidth 4 -draw 'circle 128,84 128,60' -draw 'polygon 100,170 156,170 142,110 114,110' -draw 'roundrectangle 92,168 164,184 8,8' \
    -stroke none -font "$FONT" -pointsize 44 -fill '#4bd16b' -annotate +138+226 '>_' \
    "$D/icon.png"
