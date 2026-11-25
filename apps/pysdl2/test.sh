TEST_NAME=pysdl2
need_pkg python3-pysdl2
ok module-present test -f /opt/python3/lib/python3.11/site-packages/sdl2/__init__.py
# without a display: the dummy video driver; the version comes from libSDL2 of the package libsdl2
contains import-and-version "SDL 2." sh -c 'PYSDL2_DLL_PATH=/opt/sdl2/lib python3 -W ignore -c "import sdl2; v = sdl2.SDL_version(); sdl2.SDL_GetVersion(v); print(\"SDL %d.%d.%d\" % (v.major, v.minor, v.patch))"'
contains dummy-window "ok" sh -c 'PYSDL2_DLL_PATH=/opt/sdl2/lib SDL_VIDEODRIVER=dummy python3 -W ignore -c "
import sdl2
assert sdl2.SDL_Init(sdl2.SDL_INIT_VIDEO) == 0
w = sdl2.SDL_CreateWindow(b\"t\", 0, 0, 64, 48, sdl2.SDL_WINDOW_SHOWN)
assert w and sdl2.SDL_GetWindowSurface(w)
sdl2.SDL_Quit(); print(\"ok\")"'
summary
