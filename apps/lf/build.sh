#!/bin/bash
# Cross-build lf for the N900 (Go, static). Runs in the Workshop or on the host (make -C apps/lf build).
# Output: /project/build/out/lf-r$VERSION/lf
set -euo pipefail
export GO_LDFLAGS="-X main.gVersion=r${VERSION:-41}"      # lf prints this with -version (go install does not set it)
exec "$(dirname "$0")/../../scripts/go-install.sh" github.com/gokcehan/lf "r${VERSION:-41}" lf
