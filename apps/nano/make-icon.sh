#!/bin/bash
# Draw the menu icon of nano -> icon.png next to this script (see scripts/icon-lib.sh).
set -euo pipefail
D="$(cd "$(dirname "$0")" && pwd)"
. "$D/../../scripts/icon-lib.sh"

# a text page with lines of text and the inverted shortcut bar of nano at the bottom
icon_base \
    -fill '#f2f2f2' -draw 'roundrectangle 40,34 216,176 10,10' \
    -fill '#4b5b6c' -draw 'roundrectangle 58,54 190,62 3,3' -draw 'roundrectangle 58,76 168,84 3,3' \
    -draw 'roundrectangle 58,98 196,106 3,3' -draw 'roundrectangle 58,120 150,128 3,3' \
    -fill '#4bd16b' -draw 'rectangle 154,118 160,134' \
    -fill '#c9d3dd' -draw 'roundrectangle 40,190 120,222 6,6' -draw 'roundrectangle 136,190 216,222 6,6' \
    -font "$FONT" -pointsize 26 -fill "$BASE" -annotate +50+214 '^G' -annotate +146+214 '^X' \
    "$D/icon.png"
