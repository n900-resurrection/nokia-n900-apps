#!/bin/bash
# Draw the menu icon of ncdu -> icon.png next to this script (see scripts/icon-lib.sh).
set -euo pipefail
D="$(cd "$(dirname "$0")" && pwd)"
. "$D/../../scripts/icon-lib.sh"

# the bars of a disk usage list (the longest one marked)
icon_base \
    -fill '#3d9bd9' -draw 'roundrectangle 36,50 220,82 6,6' \
    -fill '#4bd16b' -draw 'roundrectangle 36,100 170,132 6,6' \
    -fill '#e8a63a' -draw 'roundrectangle 36,150 120,182 6,6' \
    -fill '#c9d3dd' -draw 'roundrectangle 36,198 76,214 5,5' \
    "$D/icon.png"
