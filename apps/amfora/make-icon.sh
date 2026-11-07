#!/bin/bash
# Draw the menu icon of amfora -> icon.png next to this script (see scripts/icon-lib.sh).
set -euo pipefail
D="$(cd "$(dirname "$0")" && pwd)"
. "$D/../../scripts/icon-lib.sh"

# an amphora (a two-handled jar) in the colours of Gemini space
icon_base \
    -fill '#d9a441' -draw 'roundrectangle 88,84 168,210 40,40' \
    -fill '#d9a441' -draw 'rectangle 112,52 144,92' -draw 'rectangle 102,44 154,58' \
    -fill none -stroke '#d9a441' -strokewidth 9 -draw 'arc 62,84 114,140 90,270' -draw 'arc 142,84 194,140 270,450' -stroke none \
    -fill '#8a5a14' -draw 'rectangle 96,128 160,136' -draw 'rectangle 100,152 156,158' \
    -font "$FONT" -pointsize 26 -fill '#4bd1e0' -annotate +176+226 'gmi' \
    "$D/icon.png"
