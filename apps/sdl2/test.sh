TEST_NAME=libsdl2
need_pkg libsdl2
ok library-present test -f /opt/sdl2/lib/libSDL2-2.0.so.0
ok no-missing-libs sh -c '! ldd /opt/sdl2/lib/libSDL2-2.0.so.0 2>&1 | grep -q "not found"'
contains version "SDL 2.30" sdl2-info
contains video-x11 "x11" sdl2-info
contains audio-alsa "alsa" sdl2-info
contains audio-pulse "pulse" sdl2-info
# the dummy drivers need neither a display nor a sound card
ok dummy-audio-beep sh -c 'SDL_AUDIODRIVER=dummy sdl2-info --beep 200 | grep -q "audio=dummy"'
# a window needs the X server of the phone: only when there is a display (the emulated phone has none)
if [ -n "${DISPLAY:-}" ] && command -v xdpyinfo >/dev/null 2>&1; then
    contains window "window surface 800x480" sdl2-info --window 500
else
    skip window "no X display here: run  sdl2-info --window  on the phone"
fi
summary
