# nxengine-evo

NXEngine-evo 2.6.5-1 (GPL-3.0, <https://github.com/nxengine/nxengine-evo>): an engine for Cave Story on SDL 2. The sources are not changed.
Cave Story is a freeware game by Daisuke "Pixel" Amaya and **is not in the package**.

## Game data (once)

1. Copy the **whole folder** of the English Cave Story 1.0.0.6 (`Doukutsu.exe` and the folder `data`) to the phone, for example into MyDocs. The engine needs both:
   the pictures (`Loading.pbm`, `Stage`, `Npc` ...) are in `data`, the sounds, credit pictures and stage data are taken out of the exe.
2. Run `nxengine-evo-setup /home/user/MyDocs/CaveStory` (without an argument MyDocs and the home folder are searched); the menu entry does it the first time
   in a terminal. `nxextract` writes `pxt/`, `endpic/` and `stage.dat` into `~/.local/share/nxengine/data`, the rest of the original `data` is copied there
   except what the engine brings itself in `/opt/nxengine-evo/share/nxengine/data` (its improved files win).
3. Start **NXEngine-evo (Cave Story)** from the menu or `nxengine-evo`.

## Build

`make -C apps/nxengine-evo build` (cmake; depends on `sdl2`, `sdl2-mixer`, `sdl2-image`, built by `make`), `make debs APP=nxengine-evo`, tests `make emu-test APP=nxengine-evo`
(no game data: files, libraries, the launcher and setup messages, the extractor) and on the phone `make -C apps/nxengine-evo test`.

What had to be done for GCC 13 and glibc 2.5 (nothing in the sources):

| Problem | Remedy |
|---|---|
| `std::isinf(double) conflicts with a previous declaration` (`<math.h>` of glibc 2.5 and the libstdc++ built for glibc 2.39) | `-D_GLIBCXX_HAVE_OBSOLETE_ISINF/ISNAN` in `scripts/maemo-g++` (the repository maemo-toolchain) |
| `CLOCK_REALTIME_COARSE` (spdlog; kernel 2.6.32) | `maemo-compat.h` maps the coarse clocks to the exact ones |
| `uint8_t does not name a type` (missing `#include <cstdint>`) | `-include cstdint` in the toolchain file of `build.sh` |
| `find_package(JPEG)` although the code does not use it | `libjpeg62-dev` is in the sysroot (the SDK mirror) |

The launcher sets `SDL_RENDER_DRIVER=software`: the engine asks for an accelerated renderer, which this SDL 2 (without OpenGL) does not have, and gives up with "Couldn't find matching render driver" unless the software one is named.
In the emulator the engine starts without the game data, initialises the software renderer, the sound system (dummy) and loads its font; then it stops for the missing `Loading.pbm`.

Not tried: the game itself (it needs the data), speed at 800x480 on the phone, touch and keyboard control (the N900 has no gamepad: keys only), sound.
