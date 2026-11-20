#!/bin/bash
# Draw the menu icon of lf -> icon.png next to this script (see scripts/icon-lib.sh).
set -euo pipefail
D="$(cd "$(dirname "$0")" && pwd)"
. "$D/../../scripts/icon-lib.sh"

# an open folder with three lines (files), and the prompt of a terminal
icon_base \
    -fill '#e8b53a' -draw 'roundrectangle 30,66 226,200 14,14' -draw 'polygon 30,80 30,52 100,52 118,70 118,80' \
    -fill '#f6d36b' -draw 'polygon 24,108 232,108 214,206 42,206' \
    -fill '#8a6a12' -draw 'roundrectangle 68,128 188,138 5,5' -draw 'roundrectangle 68,150 168,160 5,5' -draw 'roundrectangle 68,172 148,182 5,5' \
    -font "$FONT" -pointsize 44 -fill '#4bd16b' -annotate +138+226 '>_' \
    "$D/icon.png"
