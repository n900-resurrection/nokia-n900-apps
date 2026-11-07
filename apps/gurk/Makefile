# gurk-rs (Signal client for the terminal) for Maemo 5: cross build with Rust (static musl). Targets and conventions: ../../mk/app.mk
# Needs the Rust toolchain of apps/rust (make -C apps/rust build), musl cross gcc and build tools are fetched by build.sh.
override APP     := gurk
VERSION ?= 0.10.2
REV     ?= 1maemo1
RUN_CMD := TERM=xterm /usr/bin/gurk --version
include ../../mk/app.mk
