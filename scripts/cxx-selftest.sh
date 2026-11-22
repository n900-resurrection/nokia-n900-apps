#!/bin/bash
# Run INSIDE the Workshop: builds the C++ self-tests (tests/cxx/*.cpp) with scripts/maemo-g++ and runs them under qemu-user with the Fremantle
# sysroot (glibc 2.5). On the phone: DEVICE=n900 scripts/cxx-selftest.sh copies them to /home/user/cpptest and runs them there as well.
set -euo pipefail
PROJ="${PROJ:-/project}"
OUT="$PROJ/build/cxx-selftest"; mkdir -p "$OUT"
for src in "$PROJ"/tests/cxx/*.cpp; do
    n=$(basename "$src" .cpp)
    "$PROJ/scripts/maemo-g++" -std=gnu++17 -O2 "$src" -o "$OUT/$n"
    ver=$(arm-linux-gnueabi-objdump -T "$OUT/$n" | grep -oE 'GLIBC_[0-9.]+' | sort -uV | tail -1)
    echo "== $n (needs at most $ver)"
    qemu-arm -L "$PROJ/sysroot" "$OUT/$n"
done
if [ -n "${DEVICE:-}" ]; then
    ssh "$DEVICE" 'mkdir -p /home/user/cpptest'
    scp -q "$OUT"/runtime "$OUT"/filesystem-time "$DEVICE":/home/user/cpptest/
    for n in runtime filesystem-time; do echo "== $n on $DEVICE"; ssh "$DEVICE" "/home/user/cpptest/$n"; done
fi
