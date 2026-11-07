#!/bin/bash
# Draw the menu icon of micro -> icon.png next to this script (see scripts/icon-lib.sh).
set -euo pipefail
D="$(cd "$(dirname "$0")" && pwd)"
. "$D/../../scripts/icon-lib.sh"

# an editor window: a title row, line numbers and code lines, a cursor
icon_base \
    -fill '#1b2530' -draw 'rectangle 30,40 226,216' \
    -fill '#6a3fb0' -draw 'rectangle 30,40 226,66' \
    -font "$FONT" -pointsize 22 -fill white -annotate +40+60 'micro' \
    -pointsize 20 -fill '#5a6b7c' -annotate +38+96 '1' -annotate +38+124 '2' -annotate +38+152 '3' -annotate +38+180 '4' \
    -fill '#4bd1e0' -draw 'rectangle 64,82 120,92' -fill '#e0c050' -draw 'rectangle 128,82 192,92' \
    -fill '#7f8c99' -draw 'rectangle 80,110 170,120' -draw 'rectangle 80,138 150,148' \
    -fill '#4bd16b' -draw 'rectangle 64,166 134,176' \
    -fill white -draw 'rectangle 140,162 146,182' \
    "$D/icon.png"
