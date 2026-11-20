#!/bin/bash
# Cross-build cointop (cryptocurrency tracker for the terminal) for the N900 (Go, static). Runs on the host (make -C apps/cointop build).
# Output: /project/build/out/cointop-$VERSION/cointop
set -euo pipefail
exec "$(dirname "$0")/../../scripts/go-install.sh" github.com/cointop-sh/cointop "v${VERSION:-1.6.10}" cointop
