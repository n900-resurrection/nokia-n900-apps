#!/bin/bash
# Package the built mdcat as a .deb for Maemo 5. Run INSIDE the Workshop after build.sh: make -C apps/mdcat deb
# Output: /project/build/deb/mdcat_<VERSION>-<REV>_armel.deb   (a command line tool: no menu entry)
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=mdcat
VERSION="${VERSION:-2.20.2}"
OUT="$PROJ/build/out/$PKG-$VERSION"
SRC=$(ls -d "$PROJ"/build/rust/cargo/registry/src/*/mdcat-$VERSION | head -1)
STAGE="$PROJ/build/deb/stage-$PKG"
[ -x "$OUT/mdcat" ] || { echo "Missing build output in $OUT, run build.sh first (make build)"; exit 1; }

rm -rf "$STAGE"; mkdir -p "$STAGE/opt/mdcat/bin" "$STAGE/opt/mdcat/share/doc/mdcat" "$STAGE/usr/bin"
install -m 755 "$OUT/mdcat" "$STAGE/opt/mdcat/bin/mdcat"
ln -s mdcat "$STAGE/opt/mdcat/bin/mdless"                      # started as mdless it pages its output (it looks at its own name)
ln -s "../../opt/mdcat/bin/mdcat" "$STAGE/usr/bin/mdcat"
ln -s "../../opt/mdcat/bin/mdless" "$STAGE/usr/bin/mdless"
install -m 644 "$SRC/LICENSE" "$SRC/README.md" "$SRC/CHANGELOG.md" "$SRC/config.toml.example" "$STAGE/opt/mdcat/share/doc/mdcat/"

SECTION=user/utilities
DEPENDS="libc6"
DISPLAY_NAME="mdcat"
SHORT_DESC="mdcat $VERSION shows Markdown files in the terminal"
LONG_DESC="mdcat $VERSION: like cat, but for Markdown. It renders headings, lists, quotes, tables, links and highlighted code blocks with the colours and
styles of the terminal. mdcat README.md shows a file, mdless README.md pages it (needs a pager: the package less is the better one), and
mdcat --help lists the options. Images need a terminal that can show them (the terminal of the phone cannot). Built for Maemo 5 with Rust as a
static binary (20 MB, most of it the syntax definitions for code blocks). The upstream repository is archived (2026), the last release still works.
Upstream: https://github.com/swsnr/mdcat"
MAINTAINER="elPytel (build of upstream mdcat by Sebastian Wiesner and contributors)"
# the manual page is written in AsciiDoc upstream (no asciidoctor here): --help is the reference
debpack_build
