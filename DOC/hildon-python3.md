# Hildon GUI from Python 3, and trying it on the PC

**Moved.** The emulator of the Hildon desktop and the guide to writing a GUI application in Python 3 are part of the development kit
[n900-devkit](https://github.com/n900-resurrection/n900-devkit) (the folder `devkit/` of this repository). Its documentation (in English, kept up to date):

- [devkit/docs/python-gui.md](../devkit/docs/python-gui.md): Python 3 and `ctypes`, the layer [hildonlite](../apps/hildonlite), a worked example (`devkit/apps/quick-notes`), testing in the emulator, habits of a native application
- [devkit/docs/emulator.md](../devkit/docs/emulator.md): the emulated desktop (top bar, switcher, launcher, D-Bus mocks), your application in it, `emu-shots`, `emu-test`, theme and fonts, limits

## What is specific to this repository
- The applications of this repository start in the emulator through their own `apps/<app>/hildon-run.sh` (mutt-hildon, sfeed-hildon, hildonlite, gPodder ...), with demo data in `/tmp`;
  `make hildon-run APP=<app>`, `make emulator` (the launcher shows them and every built package with a `.desktop` file in `build/deb/`), `make emu-shots APP=<app>` with `apps/<app>/shots.txt`.
- `make hildon-test` runs the unittest suite of hildonlite (`apps/hildonlite/tests/test_hildonlite.py`) with the real GTK 2 / Hildon libraries under qemu-user.
- **yt-dlp in the emulator:** the launcher creates `~/.local/bin/yt-dlp` in the emulator home (`build/emu/home`) as a wrapper of the host yt-dlp (`build/pylibs`, `make pylibs`), because the ARM Python 3
  under qemu is far too slow; QuickJS is the ARM binary of the `quickjs` package. Dependencies of a package that are our own packages (curl, quickjs for gPodder) are unpacked into the sysroot too.
- The ARM Python 3 of the emulator is the cross-built one (`make python3`, `build/out/python3-*`) when it exists, else the one downloaded with `make arm-python`.
- Why `ctypes` and not PyGTK or PyGObject (verified 2026-11-05): PyGTK (`python-gtk2`, `python2.5-hildon`, which mutt-hildon and gPodder 2 use) is Python 2 only, PyGObject needs GObject Introspection data
  that GTK 2 and Hildon do not have. A Python 3.11 package (`python3.11`) opens `HildonStackableWindow` and `HildonButton` through `ctypes` and handles signals.
