#!/bin/bash
# Cross-build mdcat (cat for Markdown: renders it in the terminal) from crates.io. Run INSIDE the Workshop (make -C apps/mdcat build).
# Static musl binary. The curl crate (images from the web) needs OpenSSL for musl: it is built here once from the sources of apps/openssl (static, no assembler)
# with the musl cross gcc (make -C apps/gurk build fetches it), into build/deps/openssl-musl-$SSLV.
# Output: /project/build/out/mdcat-$VERSION/mdcat
set -euo pipefail
PROJ=/project
SSLV=3.5.9
T="$PROJ/build/rust/musl-cross/bin/arm-linux-musleabi"
DEP="$PROJ/build/deps/openssl-musl-$SSLV"
[ -x "$T-gcc" ] || { echo "Missing $T-gcc, run: make -C apps/gurk build"; exit 1; }
if [ ! -f "$DEP/lib/libssl.a" ]; then
    f="openssl-$SSLV.tar.gz"
    [ -s "$PROJ/build/downloads/$f" ] || curl -fL --retry 3 -o "$PROJ/build/downloads/$f" "https://github.com/openssl/openssl/releases/download/openssl-$SSLV/$f"
    W="$PROJ/build/obj/openssl-musl-$SSLV"; rm -rf "$W" "$DEP"; mkdir -p "$W"
    tar -C "$W" -xzf "$PROJ/build/downloads/$f" --strip-components=1
    (cd "$W" && ./Configure linux-armv4 no-shared no-asm no-tests no-docs no-module --prefix="$DEP" --libdir=lib CC="$T-gcc" AR="$T-ar" RANLIB="$T-ranlib" \
        -mcpu=cortex-a8 -Os > "$PROJ/build/openssl-musl.log" 2>&1 \
     && make -j"$(nproc)" >> "$PROJ/build/openssl-musl.log" 2>&1 && make install_sw >> "$PROJ/build/openssl-musl.log" 2>&1) \
        || { tail -20 "$PROJ/build/openssl-musl.log"; exit 1; }
fi
export OPENSSL_DIR="$DEP" OPENSSL_STATIC=1 OPENSSL_NO_VENDOR=1
export MUSL=1 CARGO_TAIL=40
# a smaller binary (the syntax definitions of syntect are most of it): link time optimisation, size optimisation
export CARGO_PROFILE_RELEASE_LTO=true CARGO_PROFILE_RELEASE_CODEGEN_UNITS=1 CARGO_PROFILE_RELEASE_OPT_LEVEL=s CARGO_PROFILE_RELEASE_PANIC=abort
exec "$PROJ/scripts/cargo-install.sh" mdcat "${VERSION:-2.20.2}" mdcat
