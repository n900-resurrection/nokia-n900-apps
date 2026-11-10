#!/bin/bash
# Draw the icons of selfie with ImageMagick: icons/48.png and 64.png (the application icon: a camera on a dark rounded square) and the white
# glyphs of the buttons ui-*.png (64x64, transparent). The PNGs are committed; run this only to change the design.
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p icons
W='#f2f2f2'
# application icon
convert -size 256x256 xc:none -fill '#26323f' -draw 'roundrectangle 8,8 247,247 44,44' \
  -fill "$W" -draw 'roundrectangle 36,84 220,192 20,20' -draw 'roundrectangle 92,64 164,96 8,8' \
  -fill '#26323f' -draw 'circle 128,138 128,172' -fill '#3d9bd9' -draw 'circle 128,138 128,160' \
  -fill "$W" -draw 'circle 140,127 140,134' icons/256.png
for s in 64 48; do convert icons/256.png -resize ${s}x${s} icons/$s.png; done
rm icons/256.png
# shutter: ring with a filled disc
convert -size 64x64 xc:none -fill none -stroke "$W" -strokewidth 5 -draw 'circle 32,32 32,8' -fill "$W" -stroke none -draw 'circle 32,32 32,19' icons/ui-shutter.png
# switch camera: two arrows going around
convert -size 64x64 xc:none -fill none -stroke "$W" -strokewidth 5 -draw 'arc 10,10 54,54 200,320' -draw 'arc 10,10 54,54 20,140' \
  -fill "$W" -stroke none -draw 'polygon 50,28 60,28 55,38' -draw 'polygon 14,36 4,36 9,26' icons/ui-switch.png
# close
convert -size 64x64 xc:none -stroke "$W" -strokewidth 6 -draw 'line 16,16 48,48' -draw 'line 48,16 16,48' icons/ui-close.png
