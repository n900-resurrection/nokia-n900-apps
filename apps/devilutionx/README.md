# devilutionx

**Works on the phone** (2026-11-25, revision 1maemo4, tested with the full game `DIABDAT.MPQ`: smooth, about 30 fps, touch screen works, scaled to the screen, sound and music play). The files:

- `build.sh` (cross-build in the Workshop, `make -C apps/devilutionx build`), `package.sh` (`make debs APP=devilutionx`), `test.sh` (`make emu-test APP=devilutionx`, on the phone `make -C apps/devilutionx test`),
  `make-icon.sh` (the menu icon), `Makefile` (the dependencies on the SDL 2 libraries are in `DEPS`).
- Layout of the build: `apps/sdl2/sdl2-env.sh` and `apps/sdl2/sdl2-cmake.sh` (the toolchain file and the SDL 2 arguments for cmake) are shared by the cmake games.

## Game data and what was fixed for the phone

- **Data:** `DIABDAT.MPQ` (the full game, 517 501 282 bytes, SHA-256 `63fb47d9c76484024c7640d90ab6b7ec5e13f567a7e1a917b6c03a6631d3f2b0` for the copy tested here) or the shareware `spawn.mpq`
  goes to the memory card, `MyDocs/diablo` (it does not fit into `/home`). `devilutionx-launch` searches `~/.local/share/diasurgical/devilution/`, `MyDocs/diablo` and `MyDocs` (any letter case).
- **Crash at start (1maemo3):** the engine looks for its own `devilutionx.mpq` (fonts, UI) only in the data and preference folders, not in `/opt`; without it
  it stopped with `Missing file: fonts\24-00.pcx` and a segmentation fault. The launcher links the packaged archive into the preference folder.
- **White square around the mouse cursor (1maemo4):** the hardware cursor needs X cursor functions that the libraries of the phone lack. The launcher sets `Hardware Cursor=0` in `diablo.ini`,
  the game draws the hand itself.
- **Memory:** the phone has 245 MB; with the game running only 3 to 17 MB are free. Do not run two copies; installing a package while the game runs is very slow.
- **Over ssh** start the game as `DISPLAY=:0 devilutionx-launch` (without `DISPLAY` it runs without a window, only the sound plays).
- Open: whether the sound stays on during a long game (it was silent once in the dungeon with revision 1maemo2, fine with 1maemo4); `-n` skips the intro videos.
