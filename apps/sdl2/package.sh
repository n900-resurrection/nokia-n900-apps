#!/bin/bash
# Package SDL 2 as a .deb for Maemo 5. Run INSIDE the Workshop after build.sh: make -C apps/sdl2 deb
# Output: /project/build/deb/libsdl2_<VERSION>-<REV>_armel.deb   (the shared library in /opt/sdl2/lib and the tool sdl2-info; the headers stay in build/out for the builds of the games)
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=libsdl2
VERSION="${VERSION:-2.30.11}"
OUT="$PROJ/build/out/sdl2-$VERSION"
ROOT="$OUT/root/opt/sdl2"
STAGE="$PROJ/build/deb/stage-$PKG"
[ -x "$ROOT/bin/sdl2-info" ] || { echo "Missing build output in $OUT, run build.sh first (make build)"; exit 1; }

rm -rf "$STAGE"; mkdir -p "$STAGE/opt/sdl2/lib" "$STAGE/opt/sdl2/bin" "$STAGE/opt/sdl2/share/doc/libsdl2" "$STAGE/usr/bin"
cp -a "$ROOT"/lib/libSDL2-2.0.so.0 "$ROOT"/lib/libSDL2-2.0.so.0.* "$STAGE/opt/sdl2/lib/"
install -m 755 "$ROOT/bin/sdl2-info" "$STAGE/opt/sdl2/bin/sdl2-info"
ln -s ../../opt/sdl2/bin/sdl2-info "$STAGE/usr/bin/sdl2-info"
install -m 644 "$OUT/LICENSE.txt" "$STAGE/opt/sdl2/share/doc/libsdl2/LICENSE.txt"

SECTION=user/development
DEPENDS="libc6 (>= 2.5), libx11-6"
DISPLAY_NAME="SDL 2"
SHORT_DESC="SDL $VERSION: the library of games that need SDL 2 (X11, ALSA, PulseAudio)"
LONG_DESC="Simple DirectMedia Layer $VERSION for Maemo 5, in /opt/sdl2/lib (the system SDL 1.2 stays). Video through X11 with a software surface (no OpenGL or GLES), sound through ALSA or PulseAudio (SDL_AUDIODRIVER=alsa|pulseaudio), no joystick. Games built against it link with -Wl,-rpath,/opt/sdl2/lib. The command sdl2-info lists the drivers; sdl2-info --window and --beep test drawing and sound.
Upstream: https://libsdl.org/"
MAINTAINER="elPytel (build of upstream SDL by Sam Lantinga and contributors)"
debpack_build
