#!/bin/bash
# Draw the menu icon of ranger -> icon.png next to this script (see scripts/icon-lib.sh).
set -euo pipefail
D="$(cd "$(dirname "$0")" && pwd)"
. "$D/../../scripts/icon-lib.sh"

# three columns of the file manager, the middle one with the selection
icon_base \
    -fill '#3b4b5c' -draw 'roundrectangle 26,40 86,216 8,8' -draw 'roundrectangle 98,40 158,216 8,8' -draw 'roundrectangle 170,40 230,216 8,8' \
    -fill '#3d9bd9' -draw 'roundrectangle 98,88 158,116 6,6' \
    -fill '#c9d3dd' \
    -draw 'roundrectangle 34,54 78,62 3,3' -draw 'roundrectangle 34,76 70,84 3,3' -draw 'roundrectangle 34,98 76,106 3,3' -draw 'roundrectangle 34,120 64,128 3,3' \
    -draw 'roundrectangle 106,54 150,62 3,3' -draw 'roundrectangle 106,140 144,148 3,3' -draw 'roundrectangle 106,162 150,170 3,3' \
    -draw 'roundrectangle 178,54 222,62 3,3' -draw 'roundrectangle 178,76 214,84 3,3' -draw 'roundrectangle 178,98 220,106 3,3' \
    "$D/icon.png"
