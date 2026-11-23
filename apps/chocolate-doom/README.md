# chocolate-doom

**Not finished: prepared on 2026-11-23 for building on the desktop** (see TODO.md, section games). The files:

- `build.sh` (cross-build in the Workshop, `make -C apps/chocolate-doom build`), `package.sh` (`make debs APP=chocolate-doom`), `test.sh` (`make emu-test APP=chocolate-doom`, on the phone `make -C apps/chocolate-doom test`),
  `make-icon.sh` (the menu icon), `Makefile` (the dependencies on the SDL 2 libraries are in `DEPS`).
- The first build will probably need small changes; write what you change here.
- Layout of the build: `apps/sdl2/sdl2-env.sh` and `apps/sdl2/sdl2-cmake.sh` (the toolchain file and the SDL 2 arguments for cmake) are shared by the cmake games.
