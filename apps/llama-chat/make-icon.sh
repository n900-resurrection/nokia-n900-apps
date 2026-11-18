#!/bin/bash
# Draw the icons of llama-chat with ImageMagick: icon.png (256 px, for the site) and icons/48.png, icons/64.png (a speech bubble with lines of a story
# on the dark rounded square). The PNGs are committed; run this only to change the design.
set -euo pipefail
cd "$(dirname "$0")"
# ImageMagick writes the creation time into the PNG: without these options every run changes the files although the picture is the same.
convert() { command convert +set date:create +set date:modify -define png:exclude-chunk=date,time "$@"; }
mkdir -p icons
convert -size 256x256 xc:none -fill '#26323f' -draw 'roundrectangle 8,8 247,247 44,44' \
  -fill '#f2e6c8' -draw 'roundrectangle 40,50 216,176 26,26' -draw 'polygon 74,170 74,214 124,172' \
  -stroke '#8a6f3a' -strokewidth 8 -draw 'line 66,86 190,86' -draw 'line 66,112 190,112' -draw 'line 66,138 150,138' \
  icon.png
for s in 64 48; do convert icon.png -resize ${s}x${s} icons/$s.png; done
