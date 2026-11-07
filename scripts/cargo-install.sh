#!/bin/bash
# Cross-build a pure Rust command line program from crates.io for the N900 (static musl binary). Run INSIDE the Workshop:
#   scripts/cargo-install.sh <crate> <version> <binary> [extra cargo install args]
# Output: build/out/<crate>-<version>/<binary> (stripped). Needs the Rust toolchain of apps/rust (make -C apps/rust build).
# MUSL=1 in the environment selects the musl cross gcc for crates with C parts; the default glibc cross gcc suits only freestanding C (ring).
set -euo pipefail
crate=$1; version=$2; bin=$3; shift 3
ROOT=/project
D="$ROOT/build/rust"
OUT="$ROOT/build/out/$crate-$version"
export RUSTUP_HOME="$D/rustup" CARGO_HOME="$D/cargo" PATH="$D/cargo/bin:$PATH"
[ -x "$D/cargo/bin/cargo" ] || { echo "Missing Rust, run: make -C apps/rust build"; exit 1; }
TRIPLE=armv7-unknown-linux-musleabi
export CARGO_TARGET_DIR="$D/target-$crate"
# MUSL=1: the musl.cc cross gcc (fetched by apps/gurk/build.sh) for crates with C code; it must see the musl headers.
if [ "${MUSL:-0}" = 1 ]; then
    T="$D/musl-cross/bin/arm-linux-musleabi"
    [ -x "$T-gcc" ] || { echo "Missing $T-gcc, run: make -C apps/gurk build (it fetches the toolchain)"; exit 1; }
    CCBIN="$T-gcc"
else
    CCBIN=arm-linux-gnueabi-gcc
fi
export CARGO_TARGET_ARMV7_UNKNOWN_LINUX_MUSLEABI_LINKER="$CCBIN" \
       CC_armv7_unknown_linux_musleabi="$CCBIN" \
       RUSTFLAGS="-C target-cpu=cortex-a8"
rustc --version
rm -rf "$OUT"; mkdir -p "$OUT"
cargo install "$crate" --version "$version" --locked --target "$TRIPLE" --root "$OUT/cargo-root" "$@" 2>&1 | tail -${CARGO_TAIL:-15}
arm-linux-gnueabi-strip -o "$OUT/$bin" "$OUT/cargo-root/bin/$bin"
echo "== Check"
file "$OUT/$bin" | cut -c1-140
ls -l "$OUT/$bin"
echo "== qemu-user"
qemu-arm "$OUT/$bin" --version
