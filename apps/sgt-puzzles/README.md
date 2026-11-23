# sgt-puzzles

Simon Tatham's Portable Puzzle Collection (40 logic puzzles: Net, Mines, Towers, Loopy, Solo, Pattern, Map, Tents, Bridges, Galaxies, ...) built with the
**GTK 2** front end for Maemo 5. MIT licence, upstream <https://www.chiark.greenend.org.uk/~sgtatham/puzzles/>.

- The menu has one entry, **Puzzles** (`puzzles`, a GTK 2 + Hildon list of big buttons, `puzzles-launcher.c`, reads `/opt/sgt-puzzles/share/puzzles.list`).
- Every puzzle is a program, `/opt/sgt-puzzles/bin/sgt-<name>`, with a link `/usr/bin/sgt-<name>` (`sgt-net`, `sgt-mines`, ...); the prefix cannot clash with other programs.
- Build: `make -C apps/sgt-puzzles build` (cmake in the workshop, toolchain file made by `build.sh`), package: `make debs APP=sgt-puzzles`, tests: `make emu-test APP=sgt-puzzles` and on the phone `make -C apps/sgt-puzzles test`.

## What had to be changed for GTK 2.14 and glibc 2.5 (nothing in the upstream sources)

| Problem | Remedy in `build.sh` |
|---|---|
| `<tgmath.h>` of glibc 2.5 does not compile with GCC 13 (`__tgmres declared void`) | `shim/include/tgmath.h` (plain `<math.h>`), put before the sysroot headers through `MAEMO_DEPS` |
| The puzzles use the key names `GDK_KEY_*` (GTK 2.22) | a header made from `gdkkeysyms.h` of the sysroot maps them to `GDK_*`, included with `-include` |
| `gtk_widget_set_can_default` (GTK 2.18) | a macro in the same header, with the old flag macros |
| The icons are made by running preliminary puzzle programs on the build host | not possible when cross-compiling: no per-puzzle icons; the menu icon `icon.png` is drawn by `make-icon.sh` |

Not done: Hildon look of the puzzle windows (they are plain GTK windows with a menu bar), the per-puzzle menu icons, the documentation (halibut), the unfinished puzzles.
