#!/bin/bash
# Package the built bat as a .deb for Maemo 5. Run INSIDE the Workshop after build.sh: make -C apps/bat deb
# Output: /project/build/deb/bat_<VERSION>-<REV>_armel.deb   (a command line tool: no menu entry)
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=bat
VERSION="${VERSION:-0.26.1}"
OUT="$PROJ/build/out/$PKG-$VERSION"
STAGE="$PROJ/build/deb/stage-$PKG"
[ -x "$OUT/bat" ] || { echo "Missing build output in $OUT, run build.sh first (make build)"; exit 1; }

rm -rf "$STAGE"; mkdir -p "$STAGE/opt/bat/bin" "$STAGE/opt/bat/share/doc/bat" "$STAGE/usr/bin"
install -m 755 "$OUT/bat" "$STAGE/opt/bat/bin/bat"
# The busybox less of the phone does not know -R (colours), which bat passes: the default pager is cat (no paging); set BAT_PAGER to change it
cat > "$STAGE/usr/bin/bat" <<'EOS'
#!/bin/sh
BAT_PAGER=${BAT_PAGER-cat}
export BAT_PAGER
exec /opt/bat/bin/bat "$@"
EOS
chmod 755 "$STAGE/usr/bin/bat"
# batcat is the name of bat in Debian and Ubuntu (bat there is another program); scripts and docs written for them work here too
ln -s bat "$STAGE/usr/bin/batcat"
for f in "$PROJ"/build/rust/cargo/registry/src/*/bat-$VERSION/{LICENSE-MIT,LICENSE-APACHE}; do
    [ -f "$f" ] && install -m 644 "$f" "$STAGE/opt/bat/share/doc/bat/"
done

SECTION=user/utilities
DEPENDS="libc6"
DISPLAY_NAME="bat"
SHORT_DESC="bat $VERSION cat with syntax highlighting and line numbers"
LONG_DESC="bat $VERSION: shows files like cat, but with syntax highlighting, line numbers and paging (bat script.py, bat -p README.md, bat --list-languages).
Built for Maemo 5 with Rust as a static binary, without the git markers of the margin. The pager is cat by default (the less of the phone has no colour support): set BAT_PAGER to change it. Needs a terminal with colours (the menu terminal has them).
Upstream: https://github.com/sharkdp/bat"
MAINTAINER="elPytel (build of upstream bat by David Peter and contributors)"
# man page: bat.1 is made by the build script of bat; the release tarball of the same version has it ready (the arm build is only a container for the page)
BT="$PROJ/build/downloads/bat-v$VERSION-arm-unknown-linux-gnueabihf.tar.gz"
mkdir -p "$PROJ/build/downloads"
[ -s "$BT" ] || curl -fsSL --retry 3 -o "$BT" "https://github.com/sharkdp/bat/releases/download/v$VERSION/bat-v$VERSION-arm-unknown-linux-gnueabihf.tar.gz"
BTT=$(mktemp -d); tar -C "$BTT" -xzf "$BT" --wildcards '*/bat.1'
debpack_man "$BTT"/*/bat.1
rm -rf "$BTT"
debpack_build
