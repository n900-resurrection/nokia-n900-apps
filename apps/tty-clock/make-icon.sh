#!/bin/bash
# Draw the menu icon of tty-clock -> icon.png next to this script (see scripts/icon-lib.sh).
set -euo pipefail
D="$(cd "$(dirname "$0")" && pwd)"
. "$D/../../scripts/icon-lib.sh"

# digital time
icon_base -font "$FONT" -pointsize 74 -fill '#4bd16b' -annotate +20+150 '12:34' \
    -fill '#2f8a47' -draw 'rectangle 34,172 222,180' \
    "$D/icon.png"
