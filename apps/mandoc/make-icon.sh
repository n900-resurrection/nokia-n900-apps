#!/bin/bash
# Draw the icon of mandoc -> icon.png next to this script (see scripts/icon-lib.sh).
set -euo pipefail
D="$(cd "$(dirname "$0")" && pwd)"
. "$D/../../scripts/icon-lib.sh"

# the first line of a man page: .TH
icon_base -font "$FONT" -pointsize 96 -fill '#e8d28a' -annotate +22+125 '.TH' \
    -pointsize 52 -fill '#9ab0c4' -annotate +24+195 'man(1)' \
    "$D/icon.png"
