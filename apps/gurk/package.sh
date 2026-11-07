#!/bin/bash
# Package the built gurk (static musl binary) as a .deb for Maemo 5. Run INSIDE the Workshop after build.sh: make -C apps/gurk deb
# Output: /project/build/deb/gurk_<VERSION>-<REV>_armel.deb
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=gurk
VERSION="${VERSION:-0.10.2}"
BIN="$PROJ/build/rust/gurk"
SRC="$PROJ/build/rust/gurk-rs"
STAGE="$PROJ/build/deb/stage-$PKG"
[ -x "$BIN" ] || { echo "Missing $BIN, run build.sh first (make build)"; exit 1; }

rm -rf "$STAGE"
mkdir -p "$STAGE/opt/$PKG/bin" "$STAGE/opt/$PKG/share/doc/$PKG" "$STAGE/usr/bin"
install -m 755 "$BIN" "$STAGE/opt/$PKG/bin/gurk"
ln -s "../../opt/$PKG/bin/gurk" "$STAGE/usr/bin/gurk"
install -m 644 "$SRC/LICENSE-AGPL-3.0" "$STAGE/opt/$PKG/share/doc/$PKG/LICENSE-AGPL-3.0"
cat > "$STAGE/opt/$PKG/share/doc/$PKG/README.Maemo" <<EOT
gurk $VERSION (https://github.com/boxdot/gurk-rs, commit $(git -C "$SRC" rev-parse --short HEAD), AGPL-3.0-or-later) built for Maemo 5 by apps/gurk of
the N900 project: Rust, static musl binary, no dependencies. The source is the upstream repository at that commit; the build recipe is in apps/gurk/build.sh.
First start: gurk shows a QR code; scan it in the Signal app of your main phone (Settings > Linked devices) to link this phone.
Data: ~/.config/gurk/gurk.toml and ~/.local/share/gurk/*.sqlite (the keys of the linked device: keep them private, the files are chmod 600).
Remove the device in Signal on the main phone when you stop using it.
EOT
debpack_desktop "Signal (gurk)" "/usr/bin/gurk" "$PROJ/apps/gurk/icon.png"

SECTION=user/network
DEPENDS="libc6"
DISPLAY_NAME="gurk (Signal)"
SHORT_DESC="gurk $VERSION Signal messenger client for the terminal"
LONG_DESC="gurk $VERSION, a terminal client for the Signal messenger (a linked device of your account: scan the QR code on the first start).
Built for Maemo 5 with Rust as a static binary (TLS 1.3, SQLite with encryption), 23 MB. It needs about 7 MB of RAM when idle; the first
start is slow (keys, first synchronisation). Keys: Tab/arrows to move, F1 help, Ctrl-C quits. Data is stored in ~/.config/gurk and ~/.local/share/gurk.
Upstream: https://github.com/boxdot/gurk-rs"
MAINTAINER="elPytel (build of upstream gurk-rs by boxdot and contributors)"
debpack_build
