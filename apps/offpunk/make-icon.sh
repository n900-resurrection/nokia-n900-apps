#!/bin/bash
# Draw the menu icon of offpunk -> icon.png next to this script (see scripts/icon-lib.sh).
set -euo pipefail
D="$(cd "$(dirname "$0")" && pwd)"
. "$D/../../scripts/icon-lib.sh"

# a globe (circle, meridians, equator) in punk pink on the dark base, a small "gemini" twin at the corner, and the prompt of a terminal
icon_base \
    -fill '#d6348a' -draw 'circle 128,112 128,40' \
    -fill none -stroke '#1b1b1b' -strokewidth 6 -draw 'ellipse 128,112 34,72 0,360' -draw 'line 56,112 200,112' -draw 'line 128,40 128,184' -draw 'ellipse 128,112 72,26 0,360' \
    -stroke none -font "$FONT" -pointsize 44 -fill '#4bd16b' -annotate +138+226 '>_' \
    "$D/icon.png"
