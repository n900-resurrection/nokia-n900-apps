#!/bin/bash
# Draw the menu icon of cbonsai -> icon.png next to this script (see scripts/icon-lib.sh).
set -euo pipefail
D="$(cd "$(dirname "$0")" && pwd)"
. "$D/../../scripts/icon-lib.sh"

# a bonsai tree in a pot
icon_base \
    -fill '#8a5a33' -draw 'polygon 118,200 138,200 146,150 132,118 112,150' \
    -fill none -stroke '#8a5a33' -strokewidth 9 -draw 'polyline 128,150 92,118 78,92' \
    -draw 'polyline 130,128 168,104 184,86' \
    -stroke none \
    -fill '#2e9e4a' -draw 'circle 84,84 84,52' -draw 'circle 128,66 128,32' -draw 'circle 180,80 180,50' \
    -fill '#46c463' -draw 'circle 108,100 108,76' -draw 'circle 156,98 156,74' \
    -fill '#e8a3b6' -draw 'circle 70,70 70,63' -draw 'circle 150,52 150,45' -draw 'circle 190,92 190,85' \
    -fill '#c0603a' -draw 'polygon 78,200 178,200 168,232 88,232' \
    "$D/icon.png"
