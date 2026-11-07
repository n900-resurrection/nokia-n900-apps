#!/bin/bash
# Draw the menu icon of tmux -> icon.png next to this script (see scripts/icon-lib.sh).
set -euo pipefail
D="$(cd "$(dirname "$0")" && pwd)"
. "$D/../../scripts/icon-lib.sh"

# a terminal split into panes with the green status line of tmux at the bottom
icon_base \
    -fill '#1b2530' -draw 'rectangle 30,40 226,196' \
    -fill none -stroke '#5a6b7c' -strokewidth 4 -draw 'line 128,40 128,196' -draw 'line 128,118 226,118' -stroke none \
    -font "$FONT" -pointsize 30 -fill '#4bd16b' -annotate +40+84 '$' -annotate +138+84 '$' -annotate +138+160 '$' \
    -fill '#1ba72f' -draw 'rectangle 30,196 226,226' \
    -font "$FONT" -pointsize 22 -fill '#0d1f10' -annotate +38+219 '[0] 0:sh' \
    "$D/icon.png"
