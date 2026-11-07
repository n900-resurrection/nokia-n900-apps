#!/bin/bash
# Draw the menu icon of vim9 -> icon.png next to this script (see scripts/icon-lib.sh).
set -euo pipefail
D="$(cd "$(dirname "$0")" && pwd)"
. "$D/../../scripts/icon-lib.sh"

# the green diamond of Vim with a "V" in the dark square, and a ~ column like an empty buffer
icon_base \
    -fill '#019833' -draw 'polygon 128,28 228,128 128,228 28,128' \
    -font "$FONT" -pointsize 120 -fill '#f2f2f2' -annotate +80+170 'V' \
    "$D/icon.png"
