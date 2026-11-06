#!/bin/bash
# Draw the menu icons of the console packages that have no icon upstream (ImageMagick on the host, DejaVu Sans Mono).
# Output: apps/<app>/icon.png (256x256); package.sh passes it to debpack_desktop, which makes the 48x48 and 64x64 files.
# The PNGs are committed; run this only to change the design. htop and WordGrinder use the icon of their own source tree instead.
set -euo pipefail
cd "$(dirname "$0")/.."
FONT=/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf
BASE='#26323f'      # the dark rounded square of mutt-hildon

base() { convert -size 256x256 xc:none -fill "$BASE" -draw 'roundrectangle 8,8 247,247 44,44' "$@"; }

# cmatrix: falling green characters
base -font "$FONT" -pointsize 46 \
    -fill '#1e7a3a' -annotate +34+84 '2' -annotate +34+138 '7' -annotate +34+192 'Z' \
    -fill '#35c25f' -annotate +104+60 '3' -annotate +104+114 'A' -annotate +104+168 'K' -annotate +104+222 '9' \
    -fill '#b6ffcc' -annotate +174+98 '8' -annotate +174+152 'M' \
    -fill '#3ee06d' -annotate +174+206 '0' \
    apps/cmatrix/icon.png

# tty-clock: digital time
base -font "$FONT" -pointsize 74 -fill '#4bd16b' -annotate +20+150 '12:34' \
    -fill '#2f8a47' -draw 'rectangle 34,172 222,180' \
    apps/tty-clock/icon.png

# cbonsai: a bonsai tree in a pot
base \
    -fill '#8a5a33' -draw 'polygon 118,200 138,200 146,150 132,118 112,150' \
    -fill none -stroke '#8a5a33' -strokewidth 9 -draw 'polyline 128,150 92,118 78,92' \
    -draw 'polyline 130,128 168,104 184,86' \
    -stroke none \
    -fill '#2e9e4a' -draw 'circle 84,84 84,52' -draw 'circle 128,66 128,32' -draw 'circle 180,80 180,50' \
    -fill '#46c463' -draw 'circle 108,100 108,76' -draw 'circle 156,98 156,74' \
    -fill '#e8a3b6' -draw 'circle 70,70 70,63' -draw 'circle 150,52 150,45' -draw 'circle 190,92 190,85' \
    -fill '#c0603a' -draw 'polygon 78,200 178,200 168,232 88,232' \
    apps/cbonsai/icon.png

# sfeed: the RSS symbol
base \
    -fill '#f58a1f' -draw 'roundrectangle 40,40 215,215 30,30' \
    -fill white -draw 'circle 78,178 78,157' \
    -fill none -stroke white -strokewidth 19 -draw 'arc 40,100 130,190 -90,0' -draw 'arc 4,64 166,226 -90,0' \
    apps/sfeed/icon.png

# mutt: envelope and the prompt of a terminal
base \
    -fill '#f2f2f2' -draw 'roundrectangle 36,62 220,168 12,12' \
    -fill none -stroke "$BASE" -strokewidth 9 -draw 'polyline 42,72 128,132 214,72' -stroke none \
    -font "$FONT" -pointsize 60 -fill '#4bd16b' -annotate +40+226 '>_' \
    apps/mutt/icon.png

# ranger: three columns of the file manager, the middle one with the selection
base \
    -fill '#3b4b5c' -draw 'roundrectangle 26,40 86,216 8,8' -draw 'roundrectangle 98,40 158,216 8,8' -draw 'roundrectangle 170,40 230,216 8,8' \
    -fill '#3d9bd9' -draw 'roundrectangle 98,88 158,116 6,6' \
    -fill '#c9d3dd' \
    -draw 'roundrectangle 34,54 78,62 3,3' -draw 'roundrectangle 34,76 70,84 3,3' -draw 'roundrectangle 34,98 76,106 3,3' -draw 'roundrectangle 34,120 64,128 3,3' \
    -draw 'roundrectangle 106,54 150,62 3,3' -draw 'roundrectangle 106,140 144,148 3,3' -draw 'roundrectangle 106,162 150,170 3,3' \
    -draw 'roundrectangle 178,54 222,62 3,3' -draw 'roundrectangle 178,76 214,84 3,3' -draw 'roundrectangle 178,98 220,106 3,3' \
    apps/ranger/icon.png
echo "icons written: $(ls apps/*/icon.png | wc -l)"
