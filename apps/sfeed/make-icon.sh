#!/bin/bash
# Draw the menu icon of sfeed -> icon.png next to this script (see scripts/icon-lib.sh).
set -euo pipefail
D="$(cd "$(dirname "$0")" && pwd)"
. "$D/../../scripts/icon-lib.sh"

# the RSS symbol
icon_base \
    -fill '#f58a1f' -draw 'roundrectangle 40,40 215,215 30,30' \
    -fill white -draw 'circle 78,178 78,157' \
    -fill none -stroke white -strokewidth 19 -draw 'arc 40,100 130,190 -90,0' -draw 'arc 4,64 166,226 -90,0' \
    "$D/icon.png"
