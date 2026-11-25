#!/bin/bash
# Package PySDL2 as python3-pysdl2 for Maemo 5: make -C apps/pysdl2 deb
# Output: /project/build/deb/python3-pysdl2_<VERSION>-<REV>_armel.deb
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=python3-pysdl2
VERSION="${VERSION:-0.9.17}"
OUT="$PROJ/build/out/pysdl2-$VERSION"
STAGE="$PROJ/build/deb/stage-$PKG"
[ -d "$OUT/root/opt/python3" ] || { echo "Missing build output in $OUT, run build.sh first (make build)"; exit 1; }

rm -rf "$STAGE"; mkdir -p "$STAGE"
cp -a "$OUT/root/." "$STAGE/"

SECTION=user/development
DEPENDS="python3.11, libsdl2 (>= 2.30)"
DISPLAY_NAME="PySDL2 (Python 3)"
SHORT_DESC="Python 3 bindings of SDL 2 (ctypes, pure Python)"
LONG_DESC="PySDL2 $VERSION: SDL 2 from Python 3 through ctypes (windows, events, surfaces, audio). Public domain / zlib.
It finds libSDL2 of the package libsdl2 in /opt/sdl2/lib only when PYSDL2_DLL_PATH=/opt/sdl2/lib is set: export it before 'import sdl2'.
Upstream: https://github.com/py-sdl/py-sdl2"
debpack_build
