# mandoc 1.14.6 on Maemo 5

Status 2026-11-17. Build and packaging: [Makefile](Makefile) (`make mandoc`, `make -C apps/mandoc <target>`); conventions in [../../mk/app.mk](../../mk/app.mk).

**Why:** `man` on the N900 is the BusyBox applet (`/usr/bin/man` is a link to busybox). It finds pages only along `MANPATH` and then needs `nroff`, which the phone does not have
(`sh: nroff: not found`). Our packages keep their pages in `/opt/<package>/share/man` (Maemo removes `/usr/share/man`, `docpurge`). So `man` showed nothing for any package. mandoc (<https://mandoc.bsd.lv/>,
ISC licence) formats pages itself, without groff.

## What the package does

- Installs one static binary `/opt/mandoc/bin/mandoc` (1.1 MB; `man`, `apropos`, `whatis` and `makewhatis` are links to it, mandoc looks at `argv[0]`), and links in `/usr/local/bin`.
  The BusyBox `man` stays where it is. Which `man` wins depends on the `PATH`: in a non-login shell (an `ssh host command`) `/usr/local/bin` is before `/usr/bin`, but in a **login shell** (the terminal of the phone) it is at the **end** (`/etc/profile.d/sbin-path.sh`), so the profile script below puts `/opt/mandoc/bin` first. Found the hard way: before that the BusyBox `man` won in the terminal and failed with `nroff: not found`.
- `/etc/profile.d/mandoc.sh` sets `PATH` (puts `/opt/mandoc/bin` first) and `MANPATH` at login: `/usr/share/man` and every `/opt/*/share/man`. Open a **new** terminal (or `. /etc/profile.d/mandoc.sh`) after the installation.
- `mandoc-update` (also `makewhatis`) builds the index `mandoc.db` in each of these directories. Without an index `man` works but prints a warning (`outdated mandoc.db lacks ...`) and `apropos` finds nothing.
  The index is rebuilt after the installation of the package and after every `apt-get` run (`/etc/apt/apt.conf.d/50mandoc`, `DPkg::Post-Invoke`). **Not** after `dpkg -i` or an installation through the
  Application Manager: run `mandoc-update` as root then.
- `Depends: libc6 (>= 2.5)`; the binary is linked statically (zlib for the `.gz` pages). The package carries the manual of mandoc itself (`man mandoc`, `man man.conf`, `man mdoc` is the guide to writing pages).

## Build

- `build.sh` downloads `mandoc-1.14.6.tar.gz` (SHA-256 checked) and cross-compiles it. mandoc's `configure` runs its feature tests as programs: they run under qemu-user (binfmt of the Workshop) with
  `QEMU_LD_PREFIX` set to the sysroot. `configure.local` sets the compiler, `-static`, the paths under `/opt/mandoc` and the default `MANPATH`.
- Unused: `demandoc`, `soelim` (built, not packaged).

## Verified

- On the test phone: installation with `dpkg -i`, `man mandoc`, `man tty-clock` (a `.gz` page of another package), `apropos`, no warning with the index; `make -C apps/mandoc test` (10 tests).

## Not verified

- The look in the real terminal of the phone (width, bold through `less`); characters outside ASCII (the locale of the phone has no UTF-8 test). Pages of packages installed through the Application Manager before the next `mandoc-update`.
