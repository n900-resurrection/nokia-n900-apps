#!/bin/bash
# Cross-build fd-find from crates.io. Run INSIDE the Workshop (make -C apps/fd build).
# Output: /project/build/out/fd-find-$VERSION/fd
exec /project/scripts/cargo-install.sh fd-find "${VERSION:-10.5.2}" fd
