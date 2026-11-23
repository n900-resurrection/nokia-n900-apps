#!/bin/bash
# Draw the menu icon of Brogue CE -> icon.png next to this script (see scripts/icon-lib.sh): the hero @ in a dark red dungeon.
set -euo pipefail
D="$(cd "$(dirname "$0")" && pwd)"
. "$D/../../scripts/icon-lib.sh"

icon_base -fill '#3b1a1a' -draw 'roundrectangle 24,24 231,231 30,30' \
    -fill '#5a2a22' -draw 'rectangle 40,170 216,176' -draw 'rectangle 40,206 216,212' \
    -font "$FONT" -pointsize 190 -fill '#f0d27a' -annotate +50+190 '@' \
    -fill '#c0392b' -draw 'circle 200,60 200,74' \
    "$D/icon.png"
