#!/bin/bash
# Experimental: cross-build gurk-rs (Signal client for the terminal, presage/libsignal) for the N900. Run INSIDE the Workshop:
#   make -C apps/gurk build        (needs the Rust toolchain of apps/rust: make -C apps/rust build)
# Output: build/rust/gurk, log: build/rust/gurk-build.log
# C parts of the crates (sqlite/sqlcipher, openssl, ...) are built with a musl cross gcc (musl.cc), not with the glibc cross gcc of the
# Workshop: the final binary is static musl, so the C code must see the musl headers (time_t, struct layouts).
set -euo pipefail
ROOT=/project
D="$ROOT/build/rust"
REV="${GURK_REV:-49f4295}"      # gurk-rs commit (2026-10-22), version 0.10.2
exec > >(tee "$D/gurk-build.log") 2>&1
export RUSTUP_HOME="$D/rustup" CARGO_HOME="$D/cargo" PATH="$D/cargo/bin:$PATH"
[ -x "$D/cargo/bin/cargo" ] || { echo "Missing Rust, run: make -C apps/rust build"; exit 1; }

# build tools of the crates: protobuf compiler, cmake, clang (bindgen), perl, make
need=()
for p in protobuf-compiler cmake clang libclang-dev perl make; do dpkg -s "$p" >/dev/null 2>&1 || need+=("$p"); done
[ ${#need[@]} -eq 0 ] || sudo apt-get install -y "${need[@]}"

# musl cross toolchain (static, runs on x86_64)
T="$D/musl-cross"
if [ ! -x "$T/bin/arm-linux-musleabi-gcc" ]; then
    mkdir -p "$D/dl"
    [ -s "$D/dl/arm-linux-musleabi-cross.tgz" ] || curl -fL --retry 3 -o "$D/dl/arm-linux-musleabi-cross.tgz" https://musl.cc/arm-linux-musleabi-cross.tgz
    echo "sha256 $(sha256sum "$D/dl/arm-linux-musleabi-cross.tgz" | cut -d' ' -f1)"
    rm -rf "$T" "$D/arm-linux-musleabi-cross"
    tar -C "$D" -xzf "$D/dl/arm-linux-musleabi-cross.tgz" && mv "$D/arm-linux-musleabi-cross" "$T"
fi

S="$D/gurk-rs"
if [ ! -d "$S/.git" ]; then git clone -q https://github.com/boxdot/gurk-rs.git "$S"; fi
git -C "$S" checkout -q -f "$REV"
rustc --version
cd "$S"
TRIPLE=armv7-unknown-linux-musleabi
export CARGO_TARGET_DIR="$D/target-gurk"
export CARGO_TARGET_ARMV7_UNKNOWN_LINUX_MUSLEABI_LINKER="$T/bin/arm-linux-musleabi-gcc" \
       CC_armv7_unknown_linux_musleabi="$T/bin/arm-linux-musleabi-gcc" \
       CXX_armv7_unknown_linux_musleabi="$T/bin/arm-linux-musleabi-g++" \
       AR_armv7_unknown_linux_musleabi="$T/bin/arm-linux-musleabi-ar" \
       RUSTFLAGS="-C target-cpu=cortex-a8"
cargo build --release --target "$TRIPLE" --bin gurk
cp "$D/target-gurk/$TRIPLE/release/gurk" "$D/gurk"
arm-linux-gnueabi-strip "$D/gurk" 2>/dev/null || true
file "$D/gurk" | cut -c1-140
ls -l "$D/gurk"
