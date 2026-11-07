#!/bin/bash
# Cross-build wireguard-go (user space WireGuard, Go) and wg (C, from wireguard-tools) for the N900. Run INSIDE the Workshop (make -C apps/wireguard-go build).
# The kernel 2.6.28 has no WireGuard module, so the tunnel runs in user space over /dev/net/tun.
# Output: /project/build/out/wireguard-go-$VERSION/{wireguard-go,wg,wg-quick}
set -euo pipefail
VERSION="${VERSION:-0.0.20250522}"
TOOLS_VERSION="${TOOLS_VERSION:-1.0.20250521}"
PROJ=/project
DL="$PROJ/build/downloads"
SRCDIR="$PROJ/build/src"
OUT="$PROJ/build/out/wireguard-go-$VERSION"
GO_VERSION="${GO_VERSION:-1.24.13}"
GODIR="$PROJ/build/go"
[ -x "$GODIR/go$GO_VERSION/bin/go" ] || { echo "Missing the Go toolchain, run: make -C apps/go build"; exit 1; }
mkdir -p "$DL" "$SRCDIR"
rm -rf "$OUT"; mkdir -p "$OUT"

fetch() {  # fetch <url> <file>
    [ -s "$DL/$2" ] || curl -fL --retry 3 -o "$DL/$2" "$1"
    echo "sha256 $(sha256sum "$DL/$2" | cut -d' ' -f1)  $2"
}
fetch "https://git.zx2c4.com/wireguard-go/snapshot/wireguard-go-$VERSION.tar.xz" "wireguard-go-$VERSION.tar.xz"
fetch "https://git.zx2c4.com/wireguard-tools/snapshot/wireguard-tools-$TOOLS_VERSION.tar.xz" "wireguard-tools-$TOOLS_VERSION.tar.xz"
rm -rf "$SRCDIR/wireguard-go-$VERSION" "$SRCDIR/wireguard-tools-$TOOLS_VERSION"
tar -C "$SRCDIR" -xJf "$DL/wireguard-go-$VERSION.tar.xz"
tar -C "$SRCDIR" -xJf "$DL/wireguard-tools-$TOOLS_VERSION.tar.xz"

# 1. wireguard-go (the patched Go toolchain of apps/go: epoll_pwait does not exist in the 2.6.28 kernel)
export GOROOT="$GODIR/go$GO_VERSION" PATH="$GODIR/go$GO_VERSION/bin:$PATH"
export GOCACHE="$GODIR/cache" GOPATH="$GODIR/gopath" GOTOOLCHAIN=local GOFLAGS=-mod=mod
(cd "$SRCDIR/wireguard-go-$VERSION" \
    && GOOS=linux GOARCH=arm GOARM=7 CGO_ENABLED=0 go build -trimpath -ldflags="-s -w -X main.Version=$VERSION" -o "$OUT/wireguard-go" .)

# 2. wg (configuration tool, talks to wireguard-go through the socket in /var/run/wireguard)
# (CFLAGS in the environment, not on the command line: the Makefile appends its own -isystem uapi/linux with +=)
# NLM_F_DUMP_INTR is missing in the 2.6.28 headers (the netlink code is only used with a kernel module; wireguard-go uses the socket)
CFLAGS="-Os -D_GNU_SOURCE -DNLM_F_DUMP_INTR=0x10 -include $PROJ/scripts/maemo-compat.h" make -C "$SRCDIR/wireguard-tools-$TOOLS_VERSION/src" wg CC="$PROJ/scripts/maemo-gcc" \
    > "$OUT/wg-build.log" 2>&1 || { grep -E 'error' "$OUT/wg-build.log" | head -20; tail -15 "$OUT/wg-build.log"; exit 1; }
arm-linux-gnueabi-strip -o "$OUT/wg" "$SRCDIR/wireguard-tools-$TOOLS_VERSION/src/wg"
cp "$SRCDIR/wireguard-tools-$TOOLS_VERSION/src/wg-quick/linux.bash" "$OUT/wg-quick"
cp "$SRCDIR/wireguard-go-$VERSION/LICENSE" "$OUT/LICENSE"
echo "== Check"
file "$OUT/wireguard-go" "$OUT/wg" | cut -c1-150
arm-linux-gnueabi-readelf -d "$OUT/wg" | grep NEEDED
echo -n "wg highest glibc symbol: "; arm-linux-gnueabi-objdump -T "$OUT/wg" | grep -oE 'GLIBC_[0-9.]+' | sort -uV | tail -1
ls -l "$OUT"
