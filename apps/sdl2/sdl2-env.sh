# Sourced by the build.sh of the SDL 2 libraries (sdl2-image, sdl2-mixer, sdl2-ttf): where the built SDL 2 is, and the environment that lets
# their configure find it (the cross SDL 2 sits in build/out/sdl2-<version>/root/opt/sdl2, not in /opt/sdl2 of the host).
SDL2_VERSION="${SDL2_VERSION:-2.30.11}"
SDLOUT="$PROJ/build/out/sdl2-$SDL2_VERSION"
SDLROOT="$SDLOUT/root/opt/sdl2"
[ -f "$SDLROOT/lib/libSDL2.so" ] || { echo "Missing SDL 2 ($SDLROOT), run: make sdl2"; exit 1; }
# pkg-config: sdl2.pc has prefix=/opt/sdl2; with the sysroot dir set to the install root the -I/-L paths become the real ones
export PKG_CONFIG_LIBDIR="$SDLROOT/lib/pkgconfig:$SR/usr/lib/pkgconfig" PKG_CONFIG_SYSROOT_DIR="$SDLOUT/root"
export SDL2_CONFIG=/nonexistent   # use pkg-config, not the sdl2-config of the host
