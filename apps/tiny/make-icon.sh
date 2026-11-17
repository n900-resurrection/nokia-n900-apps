#!/bin/bash
# Draw the icon of TINY -> icon.png next to this script (see scripts/icon-lib.sh).
set -euo pipefail
D="$(cd "$(dirname "$0")" && pwd)"
. "$D/../../scripts/icon-lib.sh"

# the name in neon cyan, and a few bars of the neural monitor under it
icon_base -font "$FONT" -pointsize 84 -fill '#35e0f5' -gravity north -annotate +0+34 'TINY' \
    -fill '#4be39a' -draw 'roundrectangle 40,142 200,152 4,4' \
    -fill '#35e0f5' -draw 'roundrectangle 40,162 168,172 4,4' \
    -fill '#ff5fb8' -draw 'roundrectangle 40,182 120,192 4,4' \
    -fill '#e8c04a' -draw 'roundrectangle 40,202 148,212 4,4' \
    "$D/icon.png"
