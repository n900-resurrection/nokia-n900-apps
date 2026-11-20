# chess-tui (chess in the terminal, vs a UCI engine, Lichess) for Maemo 5: cross build with Rust (static musl). Targets and conventions: ../../mk/app.mk
# Needs the Rust toolchain of apps/rust (make -C apps/rust build) and the musl cross gcc that apps/gurk/build.sh fetches.
override APP     := chess-tui
VERSION ?= 2.8.1
REV     ?= 1maemo1
RUN_CMD := TERM=xterm /usr/bin/chess-tui
include ../../mk/app.mk
