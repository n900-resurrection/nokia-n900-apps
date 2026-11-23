#!/bin/bash
# Draw the menu icon of the puzzles -> icon.png next to this script (see scripts/icon-lib.sh): a 3x3 board of tiles, one of them turned (like Net).
set -euo pipefail
D="$(cd "$(dirname "$0")" && pwd)"
. "$D/../../scripts/icon-lib.sh"

args=()
colours=('#3d7fe0' '#e0b43d' '#3dc2a0' '#d9643a' '#3d7fe0' '#8e5ad6' '#3dc2a0' '#e0b43d' '#d9643a')
for i in 0 1 2 3 4 5 6 7 8; do
    x=$((34 + (i % 3) * 66)); y=$((34 + (i / 3) * 66))
    args+=(-fill "${colours[$i]}" -draw "roundrectangle $x,$y $((x + 58)),$((y + 58)) 10,10")
done
# a light dot in four tiles, a bar in the middle one: the look of a solved board
args+=(-fill '#f2f2f2' -draw 'circle 63,63 63,73' -draw 'circle 195,195 195,205' -draw 'rectangle 118,124 138,132' -draw 'rectangle 124,118 132,138')
icon_base "${args[@]}" "$D/icon.png"
