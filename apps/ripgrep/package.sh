#!/bin/bash
# Package the built ripgrep as a .deb for Maemo 5. Run INSIDE the Workshop after build.sh: make -C apps/ripgrep deb
# Output: /project/build/deb/ripgrep_<VERSION>-<REV>_armel.deb   (a command line tool: no menu entry)
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=ripgrep
VERSION="${VERSION:-15.2.0}"
OUT="$PROJ/build/out/$PKG-$VERSION"
STAGE="$PROJ/build/deb/stage-$PKG"
[ -x "$OUT/rg" ] || { echo "Missing build output in $OUT, run build.sh first (make build)"; exit 1; }

rm -rf "$STAGE"; mkdir -p "$STAGE/opt/ripgrep/bin" "$STAGE/opt/ripgrep/share/doc/ripgrep" "$STAGE/usr/bin"
install -m 755 "$OUT/rg" "$STAGE/opt/ripgrep/bin/rg"
ln -s "../../opt/ripgrep/bin/rg" "$STAGE/usr/bin/rg"
# licence texts of the crate (MIT / Unlicense) from the cargo registry
for f in "$PROJ"/build/rust/cargo/registry/src/*/ripgrep-$VERSION/{LICENSE-MIT,UNLICENSE,COPYING}; do
    [ -f "$f" ] && install -m 644 "$f" "$STAGE/opt/ripgrep/share/doc/ripgrep/"
done

SECTION=user/utilities
DEPENDS="libc6"
DISPLAY_NAME="ripgrep"
SHORT_DESC="ripgrep $VERSION fast recursive text search (rg)"
LONG_DESC="ripgrep $VERSION (rg): searches directories recursively for a regular expression, respects .gitignore, skips binary and hidden files, and is
much faster than grep -r. Example: rg -n 'TODO' ~/src   or   rg --files | rg png. Built for Maemo 5 with Rust as a static binary (without PCRE2).
Upstream: https://github.com/BurntSushi/ripgrep"
MAINTAINER="elPytel (build of upstream ripgrep by Andrew Gallant and contributors)"
debpack_build
