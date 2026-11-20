#!/bin/bash
# Draw the menu icon of cmus -> icon.png next to this script (see scripts/icon-lib.sh).
set -euo pipefail
D="$(cd "$(dirname "$0")" && pwd)"
. "$D/../../scripts/icon-lib.sh"

# a vinyl-like record (black disc, grooves, a red label) with a music note, and the prompt of a terminal
icon_base \
    -fill '#111111' -draw 'circle 128,112 128,36' \
    -fill none -stroke '#444444' -strokewidth 2 -draw 'circle 128,112 128,52' -draw 'circle 128,112 128,66' -draw 'circle 128,112 128,80' \
    -stroke none -fill '#e0463c' -draw 'circle 128,112 128,92' -fill '#111111' -draw 'circle 128,112 128,106' \
    -fill '#f4f4f4' -draw 'ellipse 108,148 18,12 0,360' -draw 'rectangle 124,76 130,148' -draw 'polygon 130,76 166,88 166,102 130,92' \
    -font "$FONT" -pointsize 44 -fill '#4bd16b' -annotate +138+226 '>_' \
    "$D/icon.png"
