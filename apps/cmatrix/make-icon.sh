#!/bin/bash
# Draw the menu icon of cmatrix -> icon.png next to this script (see scripts/icon-lib.sh).
set -euo pipefail
D="$(cd "$(dirname "$0")" && pwd)"
. "$D/../../scripts/icon-lib.sh"

# falling green characters
icon_base -font "$FONT" -pointsize 46 \
    -fill '#1e7a3a' -annotate +34+84 '2' -annotate +34+138 '7' -annotate +34+192 'Z' \
    -fill '#35c25f' -annotate +104+60 '3' -annotate +104+114 'A' -annotate +104+168 'K' -annotate +104+222 '9' \
    -fill '#b6ffcc' -annotate +174+98 '8' -annotate +174+152 'M' \
    -fill '#3ee06d' -annotate +174+206 '0' \
    "$D/icon.png"
