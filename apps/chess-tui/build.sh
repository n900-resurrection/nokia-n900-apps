#!/bin/bash
# Cross-build chess-tui (chess in the terminal: ratatui, UCI engines, Lichess) from crates.io. Run INSIDE the Workshop (make -C apps/chess-tui build).
# Without the "sound" feature (rodio needs ALSA headers). The musl cross gcc builds the C parts of the TLS library (needs: make -C apps/gurk build once).
# Output: /project/build/out/chess-tui-$VERSION/chess-tui
export MUSL=1 CARGO_TAIL=40
exec /project/scripts/cargo-install.sh chess-tui "${VERSION:-2.8.1}" chess-tui --no-default-features
