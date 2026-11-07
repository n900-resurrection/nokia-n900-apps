#!/bin/bash
# Draw the menu icon of links -> icon.png next to this script (see scripts/icon-lib.sh).
set -euo pipefail
D="$(cd "$(dirname "$0")" && pwd)"
. "$D/../../scripts/icon-lib.sh"

# a text page: a blue title bar, grey text lines and a link underlined in white
icon_base \
    -fill '#1b2530' -draw 'rectangle 30,40 226,216' \
    -fill '#2f6fb5' -draw 'rectangle 30,40 226,70' \
    -font "$FONT" -pointsize 22 -fill white -annotate +40+63 'Links' \
    -fill '#7f8c99' -draw 'rectangle 44,92 200,100' -draw 'rectangle 44,116 170,124' \
    -fill '#4bd1e0' -draw 'rectangle 44,144 140,152' -draw 'rectangle 44,152 140,155' \
    -fill '#7f8c99' -draw 'rectangle 44,172 190,180' -draw 'rectangle 44,194 120,202' \
    "$D/icon.png"
