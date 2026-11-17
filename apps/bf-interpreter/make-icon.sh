#!/bin/bash
# Draw the icon of bf-interpreter -> icon.png next to this script (see scripts/icon-lib.sh).
set -euo pipefail
D="$(cd "$(dirname "$0")" && pwd)"
. "$D/../../scripts/icon-lib.sh"

# a piece of Brainfuck: the loop brackets around a pointer move and a plus
icon_base -font "$FONT" -pointsize 84 -fill '#e8a33d' -annotate +16+120 '[+>' \
    -pointsize 84 -fill '#7fb8e8' -annotate +16+215 '.<]' \
    "$D/icon.png"
