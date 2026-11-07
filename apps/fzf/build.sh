#!/bin/bash
# Cross-build fzf for the N900 (Go, static). Runs in the Workshop or on the host (make -C apps/fzf build).
# Output: /project/build/out/fzf-$VERSION/fzf
set -euo pipefail
exec "$(dirname "$0")/../../scripts/go-install.sh" github.com/junegunn/fzf "v${VERSION:-0.75.0}" fzf
