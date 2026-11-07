#!/bin/bash
# Cross-build ripgrep from crates.io (without the optional PCRE2). Run INSIDE the Workshop (make -C apps/ripgrep build).
# Output: /project/build/out/ripgrep-$VERSION/rg
exec /project/scripts/cargo-install.sh ripgrep "${VERSION:-15.2.0}" rg
