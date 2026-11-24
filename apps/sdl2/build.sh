#!/bin/bash
# Cross-build SDL 2 for Maemo 5 (armel, glibc 2.5, kernel 2.6.28). Run INSIDE the Workshop:
#   workshop exec n900 -- bash -c 'VERSION=2.30.11 /project/apps/sdl2/build.sh'   (or: make -C apps/sdl2 build)
# Output: /project/build/out/sdl2-$VERSION/root/opt/sdl2/{lib,include,bin} (shared libSDL2-2.0.so.0 stripped; the headers and the static library are for building
# other applications: MAEMO_DEPS=/project/build/out/sdl2-$VERSION/root/opt/sdl2, link with -L.../lib -lSDL2 -Wl,-rpath,/opt/sdl2/lib).
#
# What is on and off (verified in the emulator 2026-11-23, see DOC/games.md):
#  - video: X11 (libX11 etc. are opened at run time, so the library has no hard dependency on them), plus dummy and offscreen. No OpenGL, GLES, Vulkan, Wayland, KMS:
#    the phone has GLES 2 only through the proprietary PowerVR libraries and the sysroot has no EGL headers.
#  - audio: ALSA and PulseAudio 0.9.15 (both dlopen'd), dummy. SDL_AUDIODRIVER=alsa|pulseaudio|dummy chooses.
#  - joystick: the evdev one (the one line that needs input_absinfo.resolution is patched out above), no udev, D-Bus, IBus, HIDAPI, sensors, haptic, XInput2 (libXi 1.2 is too old).
#  - scripts/maemo-compat.h: the newer glibc symbols that glibc 2.5 lacks.
set -euo pipefail

VERSION="${VERSION:-2.30.11}"
PROJ=/project
SR="$PROJ/sysroot"
DL="$PROJ/build/downloads"
SRCDIR="$PROJ/build/src"
OBJ="$PROJ/build/obj/sdl2-$VERSION"
OUT="$PROJ/build/out/sdl2-$VERSION"
HERE="$PROJ/apps/sdl2"

[ -f "$SR/usr/include/alsa/asoundlib.h" ] && [ -f "$SR/usr/include/pulse/pulseaudio.h" ] || { echo "Missing ALSA/PulseAudio headers in the sysroot, run: make sysroot"; exit 1; }
mkdir -p "$DL" "$SRCDIR"
f="SDL2-$VERSION.tar.gz"
[ -s "$DL/$f" ] || curl -fL --retry 3 -o "$DL/$f" "https://github.com/libsdl-org/SDL/releases/download/release-$VERSION/$f"
echo "sha256 $(sha256sum "$DL/$f" | cut -d' ' -f1)  $f"
rm -rf "$SRCDIR/SDL2-$VERSION" "$OBJ" "$OUT"
tar -C "$SRCDIR" -xzf "$DL/$f"
# The kernel headers 2.6.28 lack input_absinfo.resolution (kernel 2.6.37); the joystick code of SDL uses it only to guess the type of a stick and for the scale
# of accelerometers: 0 means "unknown". Games that start SDL with SDL_INIT_JOYSTICK (Abuse) fail without a joystick subsystem.
sed -i -E 's/(absinfo(_[xy])?)(->|\.)resolution/0/g' "$SRCDIR/SDL2-$VERSION/src/joystick/linux/SDL_sysjoystick.c"
# hildon-desktop (Maemo 5) leaves the keyboard focus with its own "desktop" window when a SDL 2 window is mapped, so no key reaches the game (the mouse and
# the touch screen work). Giving the focus to the new window by hand, as SDL does when there is no window manager, fixes it (tested 2026-11-24: keys arrive).
python3 - "$SRCDIR/SDL2-$VERSION/src/video/x11/SDL_x11window.c" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
old = "    if (!data->videodata->net_wm) {\n        /* no WM means no FocusIn event, which confuses us. Force it. */"
assert old in s
s = s.replace(old, "    if (1) { /* Maemo 5: hildon-desktop does not focus the window, force it */")
open(p, 'w').write(s)
PY
# The same, but hildon-desktop moves the focus again after the window was shown (and when a game changes the video mode: Abuse makes a second window): for 4 seconds
# after every MapNotify/ConfigureNotify of a window the focus is given back to it, if it is mapped and lost it.
python3 - "$SRCDIR/SDL2-$VERSION/src/video/x11/SDL_x11events.c" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
s = s.replace("static void X11_DispatchEvent(_THIS, XEvent *xevent)\n{", "static Window maemo_focus_win;\nstatic Uint32 maemo_focus_until, maemo_focus_last;\nstatic void X11_DispatchEvent(_THIS, XEvent *xevent)\n{", 1)
for case in ("    case MapNotify:\n    {\n", "    case ConfigureNotify:\n    {\n"):
    assert case in s
    s = s.replace(case, case + "        maemo_focus_win = data->xwindow;\n        maemo_focus_until = SDL_GetTicks() + 4000;\n", 1)
old = "    SDL_zero(xevent);\n\n    /* Keep processing pending events */"
assert old in s
s = s.replace(old, """    if (maemo_focus_win && !SDL_TICKS_PASSED(SDL_GetTicks(), maemo_focus_until) && SDL_GetTicks() - maemo_focus_last >= 100) {
        Window f; int rv; XWindowAttributes wa;
        maemo_focus_last = SDL_GetTicks();
        X11_XGetInputFocus(data->display, &f, &rv);
        if (f != maemo_focus_win && X11_XGetWindowAttributes(data->display, maemo_focus_win, &wa) && wa.map_state == IsViewable) {
            X11_XSetInputFocus(data->display, maemo_focus_win, RevertToParent, CurrentTime);
        }
    }
""" + old, 1)
open(p, 'w').write(s)
PY
mkdir -p "$OBJ" "$OUT/root"
cd "$OBJ"

# pkg-config for the libraries of the sysroot (PulseAudio is found this way)
export PKG_CONFIG_LIBDIR="$SR/usr/lib/pkgconfig" PKG_CONFIG_SYSROOT_DIR="$SR"
CC="$PROJ/scripts/maemo-gcc -include $PROJ/scripts/maemo-compat.h" CFLAGS="-O2 -fPIC" \
"$SRCDIR/SDL2-$VERSION/configure" --host=arm-linux-gnueabi --prefix=/opt/sdl2 --enable-shared --enable-static \
    --enable-joystick --disable-joystick-virtual --disable-hidapi --disable-sensor --disable-haptic --disable-dbus --disable-ibus --disable-fcitx --disable-libudev \
    --disable-video-opengl --disable-video-opengles --disable-video-opengles2 --disable-video-vulkan --disable-video-wayland --disable-video-kmsdrm --disable-video-x11-xinput \
    --disable-pipewire --disable-jack --disable-sndio --disable-oss --disable-esd --disable-arts --disable-nas --disable-diskaudio \
    --enable-alsa --enable-pulseaudio --enable-video-x11 \
    > "$OUT/configure.log" 2>&1 || { tail -30 "$OUT/configure.log"; exit 1; }
grep -E '^(Video drivers|Audio drivers|Input drivers)' "$OUT/configure.log"
make -j"$(nproc)" > "$OUT/make.log" 2>&1 || { grep -E 'error|Error' "$OUT/make.log" | head -20; tail -15 "$OUT/make.log"; exit 1; }
make DESTDIR="$OUT/root" install > "$OUT/install.log" 2>&1 || { tail -15 "$OUT/install.log"; exit 1; }
ROOT="$OUT/root/opt/sdl2"
arm-linux-gnueabi-strip --strip-unneeded "$ROOT"/lib/libSDL2-2.0.so.0.*
# the diagnostic tool (sdl2-info), linked to the shared library
mkdir -p "$ROOT/bin"
"$PROJ/scripts/maemo-gcc" -O2 -include "$PROJ/scripts/maemo-compat.h" -I"$ROOT/include/SDL2" -D_REENTRANT "$HERE/sdl2-info.c" -o "$OUT/sdl2-info.unstripped" \
    -L"$ROOT/lib" -lSDL2 -lm -Wl,-rpath,/opt/sdl2/lib
arm-linux-gnueabi-strip -o "$ROOT/bin/sdl2-info" "$OUT/sdl2-info.unstripped"
cp "$SRCDIR/SDL2-$VERSION/LICENSE.txt" "$OUT/LICENSE.txt"
echo "== Check"
file "$ROOT/bin/sdl2-info" | cut -c1-140
arm-linux-gnueabi-readelf -d "$ROOT"/lib/libSDL2-2.0.so.0.* | grep NEEDED
echo -n "Highest glibc symbol: "
arm-linux-gnueabi-objdump -T "$ROOT"/lib/libSDL2-2.0.so.0.* | grep -oE 'GLIBC_[0-9.]+' | sort -uV | tail -1
ls -l "$ROOT"/lib/libSDL2-2.0.so.0.* "$ROOT/bin/sdl2-info"
