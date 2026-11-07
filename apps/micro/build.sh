#!/bin/bash
# Cross-build micro (terminal editor) for the N900: Go, static, with the patched Go toolchain of apps/go. Runs on the HOST (make -C apps/micro build).
# Output: build/out/micro-$VERSION/micro. (micro cannot be installed with `go install pkg@version`: its go.mod has replace directives.)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VERSION="${VERSION:-2.0.15}"
GO_VERSION="${GO_VERSION:-1.24.13}"
DIR="$ROOT/build/go"
[ -x "$DIR/go$GO_VERSION/bin/go" ] || { echo "Missing the Go toolchain, run: make -C apps/go build"; exit 1; }
export GOROOT="$DIR/go$GO_VERSION" PATH="$DIR/go$GO_VERSION/bin:$PATH"
export GOCACHE="$DIR/cache" GOPATH="$DIR/gopath" GOTOOLCHAIN=local GOFLAGS=-mod=mod
OUT="$ROOT/build/out/micro-$VERSION"
SRC="$ROOT/build/src/micro-$VERSION"
rm -rf "$OUT" "$SRC"; mkdir -p "$OUT" "$ROOT/build/src"
git clone -q --depth 1 --branch "v$VERSION" https://github.com/zyedidia/micro.git "$SRC"
cd "$SRC"
go generate ./runtime 2>/dev/null || true       # embeds the runtime files (colour schemes, syntax); a no-op on release tags
GOOS=linux GOARCH=arm GOARM=7 CGO_ENABLED=0 go build -trimpath \
    -ldflags="-s -w -X github.com/zyedidia/micro/v2/internal/util.Version=$VERSION -X github.com/zyedidia/micro/v2/internal/util.CommitHash=$(git rev-parse --short HEAD) -X 'github.com/zyedidia/micro/v2/internal/util.CompileDate=$(date -u +%Y-%m-%d)'" \
    -o "$OUT/micro" ./cmd/micro
cp LICENSE "$OUT/LICENSE"
file "$OUT/micro" | cut -c1-140
ls -l "$OUT/micro"
