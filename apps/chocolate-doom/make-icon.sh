#!/bin/bash
# Draw the menu icon of chocolate-doom -> icon.png next to this script (see scripts/icon-lib.sh).
set -euo pipefail
D="$(cd "$(dirname "$0")" && pwd)"
. "$D/../../scripts/icon-lib.sh"
icon_base -font "$FONT" -pointsize 190 -fill '#d9a03a' -annotate +62+190 'D' "$D/icon.png"
