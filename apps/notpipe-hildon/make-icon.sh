#!/bin/bash
# Draw the icons of notpipe-hildon with ImageMagick: icon.png (256 px, for the site) and icons/48.png, icons/64.png (a play triangle on a rounded
# screen, on the dark rounded square). The PNGs are committed; run this only to change the design.
set -euo pipefail
cd "$(dirname "$0")"
# ImageMagick writes the creation time into the PNG: without these options every run changes the files although the picture is the same.
convert() { command convert +set date:create +set date:modify -define png:exclude-chunk=date,time "$@"; }
mkdir -p icons
convert -size 256x256 xc:none -fill '#26323f' -draw 'roundrectangle 8,8 247,247 44,44' \
  -fill '#e8eef5' -draw 'roundrectangle 34,60 222,186 22,22' \
  -fill '#d6453a' -draw 'polygon 106,88 106,158 168,123' \
  -fill '#e8eef5' -draw 'roundrectangle 78,200 178,214 7,7' \
  icon.png
for s in 64 48; do convert icon.png -resize ${s}x${s} icons/$s.png; done
