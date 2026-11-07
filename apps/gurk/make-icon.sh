#!/bin/bash
# Draw the menu icon of gurk -> icon.png next to this script (see scripts/icon-lib.sh).
set -euo pipefail
D="$(cd "$(dirname "$0")" && pwd)"
. "$D/../../scripts/icon-lib.sh"

# a blue speech bubble (a Signal-like messenger) with three lines of text, and the prompt of a terminal
icon_base \
    -fill '#3a76f0' -draw 'roundrectangle 34,40 222,172 36,36' -draw 'polygon 70,160 66,214 118,168' \
    -fill white -draw 'roundrectangle 66,76 190,88 5,5' -draw 'roundrectangle 66,102 170,114 5,5' -draw 'roundrectangle 66,128 150,140 5,5' \
    -font "$FONT" -pointsize 44 -fill '#4bd16b' -annotate +138+226 '>_' \
    "$D/icon.png"
