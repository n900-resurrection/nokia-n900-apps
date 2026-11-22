#!/bin/bash
# Draw the menu icon of copyparty -> icon.png next to this script (see scripts/icon-lib.sh).
set -euo pipefail
D="$(cd "$(dirname "$0")" && pwd)"
. "$D/../../scripts/icon-lib.sh"

# a folder with an arrow up (upload) and down (download) over it, and the terminal prompt
icon_base \
    -fill '#f2b84b' -draw 'polygon 40,86 104,86 118,106 216,106 216,196 40,196' \
    -fill '#e0a22f' -draw 'rectangle 40,124 216,196' \
    -fill '#4bd16b' -draw 'polygon 90,60 114,24 138,60 124,60 124,98 104,98 104,60' \
    -fill '#4ba3d1' -draw 'polygon 170,124 190,124 190,160 204,160 180,192 156,160 170,160' \
    -font "$FONT" -pointsize 44 -fill '#f4f4f4' -annotate +150+236 '>_' \
    "$D/icon.png"
