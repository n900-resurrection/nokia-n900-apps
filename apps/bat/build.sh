#!/bin/bash
# Cross-build bat from crates.io. Run INSIDE the Workshop (make -C apps/bat build). Output: /project/build/out/bat-$VERSION/bat
# The syntax engine oniguruma (C, via the feature of the application) is built with the musl cross gcc (MUSL=1).
# Features: no libgit2 (git markers in the margin); regex-fancy is the pure Rust regex engine of the syntax highlighting.
MUSL=1 exec /project/scripts/cargo-install.sh bat "${VERSION:-0.26.1}" bat --no-default-features --features application,regex-fancy
