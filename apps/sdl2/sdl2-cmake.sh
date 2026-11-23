# Sourced by the build.sh of games that are built with cmake on SDL 2 (after sdl2-env.sh and the variables PROJ, SR, OBJ):
#   . "$PROJ/apps/sdl2/sdl2-env.sh"; . "$PROJ/apps/sdl2/sdl2-cmake.sh"
#   sdl2_cmake_setup            # writes $OBJ/toolchain.cmake and sets CMAKE_SDL_ARGS (cmake arguments that name the SDL 2 libraries)
#   cmake -G "Unix Makefiles" -DCMAKE_TOOLCHAIN_FILE="$OBJ/toolchain.cmake" $CMAKE_SDL_ARGS ... <source>
# The libraries of apps/sdl2, sdl2-image, sdl2-mixer, sdl2-ttf are found through their *-config.cmake files (CMAKE_PREFIX_PATH) and through the plain variables
# SDL2_INCLUDE_DIR / SDL2_LIBRARY (and the same for MIXER, IMAGE, TTF) for projects with an old FindSDL2.cmake. They are linked as shared libraries,
# with the run-time path /opt/sdl2/lib. Not every cmake project is happy with that: see the build.sh that uses it.
IMGROOT="$PROJ/build/out/sdl2-image-${SDL2_IMAGE_VERSION:-2.8.8}/root/opt/sdl2"
MIXROOT="$PROJ/build/out/sdl2-mixer-${SDL2_MIXER_VERSION:-2.8.1}/root/opt/sdl2"
TTFROOT="$PROJ/build/out/sdl2-ttf-${SDL2_TTF_VERSION:-2.24.0}/root/opt/sdl2"

sdl2_cmake_setup() {
    # the headers of the four libraries for every compile (SDL_mixer.h includes SDL_stdinc.h, which lies in the directory of another library)
    SDL_ISYSTEM="-isystem $SDLROOT/include/SDL2 -isystem $IMGROOT/include/SDL2 -isystem $MIXROOT/include/SDL2 -isystem $TTFROOT/include/SDL2"
    command -v cmake >/dev/null || { echo "Missing cmake in the workshop, run: make toolchain"; exit 1; }
    cat > "$OBJ/toolchain.cmake" <<EOF
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR arm)
set(CMAKE_C_COMPILER $PROJ/scripts/maemo-gcc)
set(CMAKE_CXX_COMPILER $PROJ/scripts/maemo-g++)
set(CMAKE_C_FLAGS_INIT "-include $PROJ/scripts/maemo-compat.h -O2 $SDL_ISYSTEM")
set(CMAKE_CXX_FLAGS_INIT "-O2 -include cstdint $SDL_ISYSTEM")
set(CMAKE_FIND_ROOT_PATH $SR $SDLOUT/root $IMGROOT $MIXROOT $TTFROOT)
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY BOTH)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE BOTH)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE BOTH)
EOF
    CMAKE_SDL_ARGS=(
        "-DCMAKE_PREFIX_PATH=$SDLROOT;$IMGROOT;$MIXROOT;$TTFROOT"
        "-DSDL2_INCLUDE_DIR=$SDLROOT/include/SDL2" "-DSDL2_LIBRARY=$SDLROOT/lib/libSDL2.so"
        "-DSDL2_MIXER_INCLUDE_DIR=$MIXROOT/include/SDL2" "-DSDL2_MIXER_LIBRARY=$MIXROOT/lib/libSDL2_mixer.so"
        "-DSDL2_IMAGE_INCLUDE_DIR=$IMGROOT/include/SDL2" "-DSDL2_IMAGE_LIBRARY=$IMGROOT/lib/libSDL2_image.so"
        "-DSDL2_TTF_INCLUDE_DIR=$TTFROOT/include/SDL2" "-DSDL2_TTF_LIBRARY=$TTFROOT/lib/libSDL2_ttf.so"
        "-DCMAKE_EXE_LINKER_FLAGS=-Wl,-rpath,/opt/sdl2/lib -Wl,-rpath-link,$SDLROOT/lib"
    )
}
