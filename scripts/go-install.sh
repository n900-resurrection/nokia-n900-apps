#!/bin/bash
# Cross-build a Go program for the N900 (static binary, GOARM=7, CGO off). Runs on the HOST with the patched Go toolchain of apps/go:
#   scripts/go-install.sh <module/main-package> <version> <binary>        e.g. github.com/junegunn/fzf v0.75.0 fzf
# Output: build/out/<binary>-<version>/<binary> (stripped). The toolchain is installed by: make -C apps/go build
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
pkg=$1; version=$2; bin=$3
GO_VERSION="${GO_VERSION:-1.24.13}"
DIR="$ROOT/build/go"
[ -x "$DIR/go$GO_VERSION/bin/go" ] || { echo "Missing the Go toolchain, run: make -C apps/go build"; exit 1; }
export GOROOT="$DIR/go$GO_VERSION" PATH="$DIR/go$GO_VERSION/bin:$PATH"
export GOCACHE="$DIR/cache" GOPATH="$DIR/gopath" GOTOOLCHAIN=local GOFLAGS=-mod=mod
OUT="$ROOT/build/out/$bin-${version#v}"
rm -rf "$OUT"; mkdir -p "$OUT"
go version
GOOS=linux GOARCH=arm GOARM=7 CGO_ENABLED=0 go install -trimpath -ldflags="-s -w" "$pkg@$version"
# cross compiled binaries go to $GOPATH/bin/linux_arm
mv "$GOPATH/bin/linux_arm/$bin" "$OUT/$bin"
file "$OUT/$bin" | cut -c1-140
ls -l "$OUT/$bin"
