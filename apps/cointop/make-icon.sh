#!/bin/bash
# Draw the menu icon of cointop -> icon.png next to this script (see scripts/icon-lib.sh).
set -euo pipefail
D="$(cd "$(dirname "$0")" && pwd)"
. "$D/../../scripts/icon-lib.sh"

# a gold coin with a B, a small rising chart line behind it, and the prompt of a terminal
icon_base \
    -fill none -stroke '#4bd16b' -strokewidth 8 -draw 'polyline 30,190 80,150 120,168 170,100 226,58' \
    -stroke none -fill '#f2a900' -draw 'circle 128,112 128,40' -fill '#fcd34d' -draw 'circle 128,112 128,52' \
    -font "$FONT" -pointsize 84 -fill '#8a5a00' -gravity center -annotate +0-16 'B' -gravity none \
    -pointsize 44 -fill '#4bd16b' -annotate +138+226 '>_' \
    "$D/icon.png"
