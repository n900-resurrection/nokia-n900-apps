#!/bin/bash
# Download the official Go toolchain (linux/amd64) into build/go/ and cross-compile Go programs for
# Maemo 5. Runs on the HOST (Go needs no sysroot; the output is a static binary without glibc):
#   GO_VERSION=1.24.13 apps/go/build.sh      (or: make -C apps/go build)
# Output: build/go/hello-go from src/go/hello.
#
# GOARM=7: the N900 has an ARMv7 CPU (Cortex-A8). CGO_ENABLED=0: no C, so no dependency on the
# old glibc 2.5. TLS 1.3 and the DNS resolver are implemented in Go itself.
# Caveat: new Go releases officially need Linux 3.2 or newer, the N900 runs 2.6.28. If the binary
# fails on the device, try an older GO_VERSION.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GO_VERSION="${GO_VERSION:-1.24.13}"
DIR="$ROOT/build/go"
mkdir -p "$DIR"
cd "$DIR"

f="go$GO_VERSION.linux-amd64.tar.gz"
if [ ! -x "go$GO_VERSION/bin/go" ]; then
    [ -s "$f" ] || curl -fL --retry 3 -o "$f" "https://go.dev/dl/$f"
    echo "sha256 $(sha256sum "$f" | cut -d' ' -f1)  $f"
    rm -rf go "go$GO_VERSION"
    tar xzf "$f" && mv go "go$GO_VERSION"
    # Patch for the 2.6.28 kernel of the N900: it has no epoll_pwait (ARM syscall 346, added in
    # 2.6.32), so the Go scheduler's netpoll fails with ENOSYS. epoll_wait (252) takes the same
    # first four arguments and ignores the extra ones that Go passes.
    sed -i 's/SYS_EPOLL_PWAIT   = 346/SYS_EPOLL_PWAIT   = 252/' \
        "go$GO_VERSION/src/internal/runtime/syscall/defs_linux_arm.go"
fi
export GOROOT="$DIR/go$GO_VERSION" PATH="$DIR/go$GO_VERSION/bin:$PATH"
export GOCACHE="$DIR/cache" GOFLAGS=-mod=mod GOTOOLCHAIN=local
go version

cd "$ROOT/src/go/hello"
GOOS=linux GOARCH=arm GOARM=7 CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o "$DIR/hello-go" .
file "$DIR/hello-go" | cut -c1-120
ls -l "$DIR/hello-go"
