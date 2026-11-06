#!/bin/bash
# Package the built cbonsai as a .deb for Maemo 5. Run INSIDE the Workshop after build.sh:
#   workshop exec n900 -- bash -c 'VERSION=1.4.2 REV=1maemo1 /project/apps/cbonsai/package.sh'   (or: make -C apps/cbonsai deb)
# Output: /project/build/deb/cbonsai_<VERSION>-<REV>_armel.deb
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=cbonsai
VERSION="${VERSION:-1.4.2}"
OUT="$PROJ/build/out/$PKG-$VERSION"
SRC="$PROJ/build/upstream/$PKG"
STAGE="$PROJ/build/deb/stage-$PKG"
[ -x "$OUT/$PKG" ] || { echo "Missing $OUT/$PKG, run build.sh first (make build)"; exit 1; }

rm -rf "$STAGE"
mkdir -p "$STAGE/opt/$PKG/bin" "$STAGE/opt/$PKG/share/doc/$PKG" "$STAGE/usr/bin"
install -m 755 "$OUT/$PKG" "$STAGE/opt/$PKG/bin/$PKG"
ln -s "../../opt/$PKG/bin/$PKG" "$STAGE/usr/bin/$PKG"
install -m 644 "$SRC/LICENSE" "$STAGE/opt/$PKG/share/doc/$PKG/LICENSE"
install -m 644 "$SRC/README.md" "$STAGE/opt/$PKG/share/doc/$PKG/README.md"
# The man page needs scdoc at build time; it is shipped only when build.sh could create it.
if [ -f "$OUT/cbonsai.6" ]; then
    mkdir -p "$STAGE/opt/$PKG/share/man/man6"
    gzip -9n -c "$OUT/cbonsai.6" > "$STAGE/opt/$PKG/share/man/man6/$PKG.6.gz"
fi

# The menu launcher cannot pass arguments to osso-xterm -e (not verified), and a plain "cbonsai"
# draws one tree and exits, which would close the terminal at once. So the launcher starts a
# small wrapper that grows the trees live and endlessly.
cat > "$STAGE/usr/bin/cbonsai-live" <<'WRAP'
#!/bin/sh
# Grow bonsai trees live, one after another, until q is pressed.
exec /opt/cbonsai/bin/cbonsai -l -i "$@"
WRAP
chmod 755 "$STAGE/usr/bin/cbonsai-live"
debpack_desktop "cbonsai" "/usr/bin/cbonsai-live" "$PROJ/apps/cbonsai/icon.png"

SECTION=user/other
# cbonsai draws wide characters, which the device's libncurses5 cannot do: ncursesw and panelw are
# linked statically into the binary, so there is no library dependency apart from libc.
DEPENDS="libc6 (>= 2.5)"
DISPLAY_NAME="cbonsai"
SHORT_DESC="Bonsai tree generator for the terminal"
LONG_DESC="cbonsai grows a random bonsai tree in the terminal. Run cbonsai -l to watch it grow,
cbonsai-live for an endless forest, cbonsai -h for the other options.
Built for Maemo 5 (armel, glibc 2.5) with ncursesw linked statically.
Upstream: https://gitlab.com/jallbrit/cbonsai"
debpack_build
