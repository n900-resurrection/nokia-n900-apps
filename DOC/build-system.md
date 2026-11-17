# The build system of this repository

How the applications in `apps/` are built and packaged. The container, the toolchain, the sysroot and the emulator are in the development kit
[n900-devkit](https://github.com/n900-resurrection/n900-devkit) (the folder `devkit/`, documentation in `devkit/docs/`); this page is about what sits on top of it.

## Targets
- Every directory `apps/<app>` with a `Makefile` is a target of the same name: `make curl` is `make -C apps/curl build`; `ACTION` selects another target of the application (`make curl ACTION=deb`).
  The `Makefile` of an application only sets variables and includes [mk/app.mk](../mk/app.mk) (VERSION, REV, EPOCH, DEPS, RUN_CMD, ICON_OUT ...; the conventions are in `mk/common.mk`).
- `make debs` goes through `apps/*`, builds the `.deb` of every application that has a `package.sh` and skips the ones that are up to date (stamps in `build/stamps`). `make debs APP="curl git"`
  selects some, `INSTALL=1` installs them on the phone too, `make -n debs` shows the plan. An application whose `Makefile` has a line starting with `MANUAL` (experimental, large, slow) is skipped
  unless it is named in `APP`.
- `DEPS := openssl curl` in `apps/<app>/Makefile`: the dependencies are built first and a rebuild of one of them rebuilds the application.
- `make repo` builds the apt repository `n900-repository/` from the current `.deb` files (it runs `make debs` first); see [apt-repo.md](apt-repo.md). `make updates` compares the version of every
  application with the newest upstream release (sources in `scripts/upstream.conf`).
- `make test` runs the tests of the applications on the phone (`apps/*/test.sh`, the packages must be installed); `make emu-test` runs them in an emulated phone (see the kit).

## Package versions and the epoch
`VERSION` is the upstream version, `REV` the revision of the package (`1maemo1`), the optional `EPOCH` goes in front (`1:4.8.33-1maemo2`) and is not part of the file name. Set an epoch only for a package that
has the name of a community package with an epoch (mc, git, openssh, smb): see the section about epochs in [apt-repo.md](apt-repo.md). Raise `REV` whenever the content of a package changes.

## The workshop client that does not return, and the build stamps (2026-11-12)
After long builds (GnuTLS, libstrophe, Python) the client `workshop exec` sometimes keeps running although the command inside has finished; `make` then waits for ever and processes pile up
on the host (`pgrep -af 'workshop.*exec'`).
- `INSIDE` in `mk/common.mk` (the kit) goes through `scripts/ws-exec.sh`. The command inside writes its exit code into `build/.wsrc.<pid>`; when that file exists and the client is still alive after
  `WS_GRACE` seconds (5), the client is killed and the code is used. The whole run is limited by `WS_TIMEOUT` (7200 s; exit 124, TERM then KILL). A client hung from an older run has to be killed by hand.
- **Stamps:** `build/stamps/<app>-<version>.built` and `<app>.built` are touched by `make build` only after a successful run. When a build was finished by hand (or the client hung and was killed), touch
  both stamps, otherwise make rebuilds the dependency and the applications depending on it from scratch (a rebuild wipes the prefix of the application in `build/out`; this removed the GnuTLS prefix once).
- **A stamp can also lie:** an interrupted build leaves a stamp and a half-empty `build/out/<app>-<version>/` (for example `screen`: `package.sh` stopped with `Missing build output ... run build.sh first`
  when `scripts/debpack.sh` changed and every package was repacked). `make -C apps/<app> build` repairs it.

## Icons are drawn on the host (2026-11-13)
`make-icon.sh` of an application (ImageMagick, output `icon.png` or `icons/*.png`) runs on the **host**, not in the Workshop (`mk/app.mk`, rule `$(ICONPNG)`): the Workshop has another ImageMagick that drew
the `bt-kbmouse` icons with 675 of 2304 pixels different, so a plain `make` changed PNGs that are committed. The host output is pixel-identical to the committed files; the bytes differ only where the old files
still carried time stamps (the script drops them now). Packages without an icon of their own get one from `icons/packages/<package>.png` (`scripts/make-pkg-icons.sh`: console tools show a green `>_`).

## Man pages (2026-11-17)
The phone has only the BusyBox `man` (it needs `nroff`, which is missing), so the package `mandoc` provides `man`, `apropos` and `whatis` (see [apps/mandoc/mandoc.md](../apps/mandoc/mandoc.md)). It shows
every page in `/opt/<package>/share/man/man<N>/<name>.<N>.gz`. A package puts its pages there with two helpers of `scripts/debpack.sh`, called in its `package.sh` before `debpack_build`:
- `debpack_man <file>...`: the roff files from the sources or the build directory (the section is taken from the extension, `.gz` allowed); a missing file is an error.
- `debpack_man_download <url> [name.N]`: a page that the sources we build from do not have (Go and Rust projects: age, fd, fzf; cached in `build/downloads`).
Special cases: `git` takes the pages of the official `git-manpages-<version>.tar.xz` (207 pages), `bat` the `bat.1` of its release tarball, `ripgrep` generates its page with `rg --generate man` under qemu-user,
`wget` makes `wget.1` from `wget.texi` with the doc Makefile (Perl in the container). Raising `REV` is enough to repack a package that gets a page; nothing is rebuilt.
Our own tools write their pages by hand in roff (`man(7)`, like `apps/bf-interpreter/bf.1`) as `apps/<app>/<name>.<N>`, committed next to the scripts, and install them with `debpack_man`. `make manlint` runs
`mandoc -T lint -W warning` over `apps/*/*.[1-8]` (with the ARM mandoc under qemu-user in the Workshop; the first run builds mandoc); any warning fails, and `make repo` runs it first. The date in `.TH` has to be `YYYY-MM-DD`.
Pages so far: `apt(1)` (apt-n900), `apt-transport-curl(8)` and `apt-transport-curl-check(8)`, `bf(1)`, `ntp-sync(1)`, and the overview `n900(7)` (in the package mandoc).
Without a page for now: weechat (asciidoctor), cbonsai (scdoc), busybox37, quickjs, python3.11, gurk, wireguard-go and our own tools (see the TODO list).

## The size of the repository
A `.deb` that is repacked without a change has other bytes (time stamps), so every `make repo` and commit stores a new copy of it in the git history of `n900-repository`. Reproducible packaging and other
ways to keep the repository small are in the TODO list ("Růst repozitáře n900-repository").
