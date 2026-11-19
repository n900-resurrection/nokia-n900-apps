#!/bin/bash
# Cross-build nplay (video player: ffmpeg libav* + SDL 1.2) for Maemo 5. Run INSIDE the Workshop:
#   workshop exec n900 -- bash -c 'VERSION=0.1 /project/apps/nplay/build.sh'   (or: make -C apps/nplay build)
# Output: /project/build/out/nplay-$VERSION/nplay  (stripped). The libav* libraries are linked statically from apps/ffmpeg
# (build/out/ffmpeg-*/root/opt/ffmpeg), SDL is the one of the phone (libsdl1.2).
set -euo pipefail

VERSION="${VERSION:-0.1}"
FFVERSION="${FFVERSION:-9.0.2}"
PROJ=/project
SR="$PROJ/sysroot"
FF="$PROJ/build/out/ffmpeg-$FFVERSION/root/opt/ffmpeg"
OUT="$PROJ/build/out/nplay-$VERSION"

[ -d "$SR/usr/include/SDL" ] || { echo "Missing SDL in the sysroot, run: make sysroot"; exit 1; }
[ -f "$FF/lib/libavcodec.a" ] || { echo "Missing the ffmpeg libraries ($FF), run: make ffmpeg"; exit 1; }
rm -rf "$OUT"
mkdir -p "$OUT"

MAEMO_DEPS="$FF" "$PROJ/scripts/maemo-gcc" -O2 -Wall -Wextra -D_REENTRANT -include "$PROJ/scripts/maemo-compat.h" \
    -I"$SR/usr/include/SDL" "$PROJ/apps/nplay/nplay.c" -o "$OUT/nplay.unstripped" \
    -lavformat -lavcodec -lswscale -lswresample -lavutil -lSDL -lm -lpthread -lrt -ldl \
    > "$OUT/build.log" 2>&1 || { cat "$OUT/build.log"; exit 1; }
arm-linux-gnueabi-strip -o "$OUT/nplay" "$OUT/nplay.unstripped"
rm -f "$OUT/nplay.unstripped"
grep -E "warning" "$OUT/build.log" | head || true

echo "== Check"
file "$OUT/nplay" | cut -c1-140
ls -l "$OUT/nplay"
