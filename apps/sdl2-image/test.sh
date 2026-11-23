TEST_NAME=libsdl2-image
need_pkg libsdl2-image
ok library-present test -f /opt/sdl2/lib/libSDL2_image-2.0.so.0
ok no-missing-libs sh -c '! ldd /opt/sdl2/lib/libSDL2_image-2.0.so.0 2>&1 | grep -q "not found"'
# it links the SDL 2 of the package libsdl2, not the system SDL 1.2
ok links-sdl2 sh -c 'ldd /opt/sdl2/lib/libSDL2_image-2.0.so.0 2>&1 | grep -q libSDL2-2.0'
summary
