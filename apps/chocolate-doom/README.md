# chocolate-doom

**Works on the phone** (built and tested 2026-11-24/25; see TODO.md, section games). The files:

- `build.sh` (cross-build in the Workshop, `make -C apps/chocolate-doom build`), `package.sh` (`make debs APP=chocolate-doom`), `test.sh` (on the phone `make -C apps/chocolate-doom test`),
  `make-icon.sh` (the menu icon), `n900.cfg` (settings for the phone), `chocolate-doom-launch`, `Makefile` (the dependencies on the SDL 2 libraries are in `DEPS`).
- The game data (an IWAD such as `DOOM2.WAD` or `freedoom1.wad`) is not in the package: put it in `MyDocs`.
- Layout of the build: `apps/sdl2/sdl2-env.sh` and `apps/sdl2/sdl2-cmake.sh` (the toolchain file and the SDL 2 arguments for cmake) are shared by the cmake games.
- Open: the music is silent (SDL2_mixer has no MIDI decoder); the cause of the audio shutdown hang is not known; sound was missing for a while once after a start and came back.

## What was changed for the phone (2026-11-25, revision 1maemo3)

Tested on one N900 with `DOOM2.WAD`; a time demo (`-timedemo demo1`) measures the speed.

- **Speed: 6 to 10 fps before, 36 fps now.** With `-noblit` (no output to the screen) the game ran at 120 fps, so the game was not slow, the output was: the frame was
  drawn into an ARGB8888 texture, and the software renderer of SDL 2 converted it to the RGB565 window of the phone and scaled it pixel by pixel.
  `build.sh` now makes the texture RGB565 (the window of the N900 is always RGB565, so this build is for the phone only), and `n900.cfg` switches the smooth
  scaling off (the intermediate 960x600 texture). The aspect ratio correction made no difference.
- **The game did not exit.** After *Quit* the process stayed alive for minutes (PulseAudio audio shutdown or `SDL_Quit`; with `SDL_AUDIODRIVER=dummy` it exits at once).
  `build.sh` arms `alarm(5)` at the start of `I_Quit` and `I_Error`: the exit functions (config, savegame) run first and the process ends after 5 s at the latest.
  Cause not found, the workaround is enough.
- **The keyboard has no Esc.** `n900.cfg` sets `key_menu_activate` to Backspace: Backspace, Up (Quit Game), Enter, Y.
- **Start in 26 s instead of 62 s:** the sound effects are precached at start; `snd_samplerate 22050` and a smaller cache (`n900.cfg`) halve it. The launcher shows a banner
  while the game starts. `n900.cfg` is passed with `-extraconfig`, so `chocolate-doom.cfg` of the player keeps its other values.
