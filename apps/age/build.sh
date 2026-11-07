#!/bin/bash
# Cross-build age and age-keygen for the N900 (Go, static). Runs in the Workshop or on the host (make -C apps/age build).
# Output: /project/build/out/{age,age-keygen}-$VERSION/
set -euo pipefail
V="${VERSION:-1.2.1}"
S="$(dirname "$0")/../../scripts/go-install.sh"
"$S" filippo.io/age/cmd/age "v$V" age
"$S" filippo.io/age/cmd/age-keygen "v$V" age-keygen
