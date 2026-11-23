# brogue-ce

Brogue CE 1.14.1 (Community Edition of the roguelike Brogue, AGPL-3.0, <https://github.com/tmewett/BrogueCE>) for the N900. The sources are not changed.

- One program with two interfaces: graphical (SDL 2 + SDL2_image, run with `--no-gpu`: the phone has no OpenGL) and terminal (`--term`, ncurses of the phone).
- Commands: `brogue-ce` (graphical, window `--size 2` for 800x480) and `brogue-ce-term`; two menu entries. Saves and high scores: `~/.brogue-ce`.
- Depends on `libsdl2`, `libsdl2-image` (apps/sdl2, apps/sdl2-image: `/opt/sdl2/lib`, rpath) and `libncurses5`.
- Build: `make -C apps/brogue-ce build` (`make sdl2 sdl2-image` first, the dependencies are built by `make`), package: `make debs APP=brogue-ce`, tests: `make emu-test APP=brogue-ce` (no screen: version, data, libraries, the deterministic seed catalog) and `make -C apps/brogue-ce test` on the phone.
- In the emulator the graphical title screen was drawn at 800x480 (`scripts/hildon-run.sh` runs ARM binaries; libraries through `QEMU_SET_ENV=LD_LIBRARY_PATH=...`).

Not tried on the phone: touch and keyboard control, speed without a GPU, the terminal mode (100x34 needs a bigger terminal than 80x24), saving.
