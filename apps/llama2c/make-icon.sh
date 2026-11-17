#!/bin/bash
# Draw the icon of the story teller -> icon.png next to this script (see scripts/icon-lib.sh).
set -euo pipefail
D="$(cd "$(dirname "$0")" && pwd)"
. "$D/../../scripts/icon-lib.sh"

# an open book: two pages with lines of text
icon_base -fill '#f2e6c8' -draw 'polygon 40,70 124,84 124,196 40,182' \
    -fill '#e9d8ad' -draw 'polygon 132,84 216,70 216,182 132,196' \
    -stroke '#8a6f3a' -strokewidth 5 -fill none -draw 'line 124,84 124,196' -draw 'line 132,84 132,196' \
    -stroke '#6b5a3a' -strokewidth 4 -draw 'line 54,102 112,112' -draw 'line 54,124 112,134' -draw 'line 54,146 112,156' \
    -draw 'line 144,112 202,102' -draw 'line 144,134 202,124' -draw 'line 144,156 190,148' \
    "$D/icon.png"
