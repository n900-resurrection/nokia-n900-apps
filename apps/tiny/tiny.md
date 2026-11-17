# TINY 2.1 on Maemo 5

Status 2026-11-17. Build and packaging: [Makefile](Makefile) (`make tiny`, `make tiny ACTION=deb`); conventions in [../../mk/app.mk](../../mk/app.mk).

A tiny question-answering neural network (367,000 weights, 4 layers, 96 wide, 8-bit weights, 380 kB) that reads and writes letter by letter and knows about 3,500 facts. Written for DOS and Turbo C 2.0 by
<https://github.com/WollyMonjac/Tiny-2.1> ("written by Fable 5.2 and trained by Opus 5.5"). The port, in the fork <https://github.com/n900-resurrection/Tiny-2.1> (branch `n900`):
the full-screen interface on ncurses (`conio_ncurses.c`), a layout that follows the size of the terminal, sound through `paplay`, volume keys.

## Licence: not published yet

The original has **no licence file**. The author is asked in an issue of the original repository. Until there is an answer the Makefile has a `MANUAL` line: `make debs` and `make repo` skip the package,
`make tiny ACTION=deb` builds it for tests. Remove the line (and add the licence to the package) when the author answers.

## Build

- `build.sh` clones the fork, checks out the pinned commit (`COMMIT`, now `7b61a95`; `TINY_SRC=/path` builds from a local working copy) and runs the `make` of the fork with `maemo-gcc`:
  ncurses with wide characters is linked **statically** (the phone has `libncurses5` but not `libncursesw`), `MODEL_PATH=/opt/tiny/share/tiny/TINY.BIN` tells the program where the network is.
- `NEEDED`: libm and libc; highest symbol `GLIBC_2.4`. The binary is 168 kB.

## Package `tiny`

- `Depends: libc6 (>= 2.5), pulseaudio-utils, terminfo-256color` (`paplay` plays the voice, `xterm-256color` gives the neon colours), `Section: user/games`, 470 kB.
- `/opt/tiny/bin/tiny-bin` (the program), `/opt/tiny/bin/tiny` (a launcher that sets `TERM=xterm-256color`), a link `/usr/bin/tiny`, `/opt/tiny/share/tiny/TINY.BIN`, the manual `tiny(1)`,
  the READMEs and a `NOTICE`, and a menu entry (`osso-xterm -e /usr/bin/tiny`).
- Keys: PgUp / PgDn volume (remembered in `~/.tiny-volume`), Ctrl-A help, Ctrl-S sound, Ctrl-V voice, Ctrl-T creativity, Esc quit.

## Verified

- On the test phone: installation, `make -C apps/tiny test` (8 tests: launcher, network, two answers in the plain mode, menu entry, libraries, man page), `man tiny`.
- The interface at 72x16, 72x18 and 80x25; the sound and the keys by ear (see the blog post).

## Not verified

- The menu entry (start from the menu, the size of the window), `apt-get remove`, a phone with another sound setup.
