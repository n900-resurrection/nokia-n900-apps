#!/bin/bash
# Draw the menu icon of mutt -> icon.png next to this script (see scripts/icon-lib.sh).
set -euo pipefail
D="$(cd "$(dirname "$0")" && pwd)"
. "$D/../../scripts/icon-lib.sh"

# an envelope and the prompt of a terminal
icon_base \
    -fill '#f2f2f2' -draw 'roundrectangle 36,62 220,168 12,12' \
    -fill none -stroke "$BASE" -strokewidth 9 -draw 'polyline 42,72 128,132 214,72' -stroke none \
    -font "$FONT" -pointsize 60 -fill '#4bd16b' -annotate +40+226 '>_' \
    "$D/icon.png"
