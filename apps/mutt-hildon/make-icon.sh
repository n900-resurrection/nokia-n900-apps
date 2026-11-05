#!/bin/bash
# Generate the application icons (envelope on a dark rounded square) with ImageMagick. Output: icons/<size>.png
# The PNGs are committed; run this only to change the design.
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p icons
convert -size 256x256 xc:none \
  -fill '#26323f' -draw 'roundrectangle 8,8 247,247 44,44' \
  -fill '#f2f2f2' -draw 'roundrectangle 40,76 215,182 12,12' \
  -fill none -stroke '#26323f' -strokewidth 9 -draw 'polyline 46,86 127,144 209,86' \
  -fill '#3d9bd9' -stroke none -draw 'circle 196,70 196,98' \
  icons/256.png
for s in 64 48; do convert icons/256.png -resize ${s}x${s} icons/$s.png; done
rm icons/256.png
