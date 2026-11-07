#!/bin/bash
# Cross-build amfora (Gemini browser) for the N900: Go, static, with the patched Go toolchain of apps/go. Runs in the Workshop or on the host (make -C apps/amfora build).
# Output: build/out/amfora-$VERSION/amfora. (Cloned instead of `go install pkg@version`: its go.mod has replace directives.)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VERSION="${VERSION:-1.11.0}"
GO_VERSION="${GO_VERSION:-1.24.13}"
DIR="$ROOT/build/go"
[ -x "$DIR/go$GO_VERSION/bin/go" ] || { echo "Missing the Go toolchain, run: make -C apps/go build"; exit 1; }
export GOROOT="$DIR/go$GO_VERSION" PATH="$DIR/go$GO_VERSION/bin:$PATH"
export GOCACHE="$DIR/cache" GOPATH="$DIR/gopath" GOTOOLCHAIN=local GOFLAGS=-mod=mod
OUT="$ROOT/build/out/amfora-$VERSION"
SRC="$ROOT/build/src/amfora-$VERSION"
rm -rf "$OUT" "$SRC"; mkdir -p "$OUT" "$ROOT/build/src"
git clone -q --depth 1 --branch "v$VERSION" https://github.com/makew0rld/amfora.git "$SRC"
cd "$SRC"
GOOS=linux GOARCH=arm GOARM=7 CGO_ENABLED=0 go build -trimpath \
    -ldflags="-s -w -X main.version=$VERSION -X main.commit=$(git rev-parse --short HEAD) -X main.builtBy=n900-project" -o "$OUT/amfora" .
cp LICENSE "$OUT/LICENSE"
file "$OUT/amfora" | cut -c1-140
ls -l "$OUT/amfora"
