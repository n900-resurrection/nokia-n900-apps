# mdcat (cat for Markdown; the upstream repository is archived since 2026-06, the last release works): Rust, static musl binary with OpenSSL for the curl crate.
# Targets and conventions: ../../mk/app.mk. Needs the Rust toolchain of apps/rust and the musl cross gcc that apps/gurk/build.sh fetches.
override APP     := mdcat
VERSION ?= 2.20.2
REV     ?= 1maemo1
RUN_CMD := /usr/bin/mdcat --version | head -1
include ../../mk/app.mk
