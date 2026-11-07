#!/bin/bash
# Install Rust (rustup, into build/rust) and cross-compile Rust programs for Maemo 5. Run INSIDE the Workshop (make -C apps/rust build):
#   output: build/rust/hello-rust from src/rust/hello
#
# Target armv7-unknown-linux-musleabi: a STATIC binary with its own musl libc, so the glibc 2.5 of the phone is not involved (the same
# idea as CGO_ENABLED=0 for Go). The linker is the cross gcc of the Workshop (arm-linux-gnueabi-gcc), the crt files come with Rust.
# Caveat: Rust officially needs Linux 3.2 or newer, the N900 runs 2.6.28 (no epoll_pwait, etc.); if the binary fails on the phone,
# the log of strace-less debugging goes to apps/rust/rust.md.
set -euo pipefail
ROOT=/project
D="$ROOT/build/rust"
export RUSTUP_HOME="$D/rustup" CARGO_HOME="$D/cargo"
mkdir -p "$D"
if [ ! -x "$CARGO_HOME/bin/rustc" ]; then
    [ -s "$D/rustup-init" ] || curl -fL --retry 3 -o "$D/rustup-init" https://static.rust-lang.org/rustup/dist/x86_64-unknown-linux-gnu/rustup-init
    chmod +x "$D/rustup-init"
    "$D/rustup-init" -y --no-modify-path --profile minimal --default-toolchain stable --target armv7-unknown-linux-musleabi
fi
export PATH="$CARGO_HOME/bin:$PATH"
rustc --version
rustup target add armv7-unknown-linux-musleabi >/dev/null 2>&1 || true
export CARGO_TARGET_DIR="$D/target"
# -C target-cpu=cortex-a8: the CPU of the N900 (ARMv7-A; the musleabi target is soft float, no VFP/NEON needed).
# CC_...: C parts of crates (ring) are built with the cross gcc of the Workshop (freestanding code, no libc headers of the phone involved).
export CARGO_TARGET_ARMV7_UNKNOWN_LINUX_MUSLEABI_LINKER=arm-linux-gnueabi-gcc \
       CC_armv7_unknown_linux_musleabi=arm-linux-gnueabi-gcc \
       RUSTFLAGS="-C target-cpu=cortex-a8"
for prog in hello tls async; do
    (cd "$ROOT/src/rust/$prog" && cargo build --release --target armv7-unknown-linux-musleabi)
    cp "$D/target/armv7-unknown-linux-musleabi/release/$prog-rust" "$D/$prog-rust"
    file "$D/$prog-rust" | cut -c1-140
    ls -l "$D/$prog-rust"
done
echo "== qemu-user"
qemu-arm "$D/hello-rust"
