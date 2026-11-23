#!/bin/bash
# Draw the menu icon of angband -> icon.png next to this script (see scripts/icon-lib.sh).
set -euo pipefail
D="$(cd "$(dirname "$0")" && pwd)"
. "$D/../../scripts/icon-lib.sh"
icon_base -font "$FONT" -pointsize 190 -fill '#5ed36b' -annotate +62+190 '@' "$D/icon.png"
