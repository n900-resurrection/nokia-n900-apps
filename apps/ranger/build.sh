#!/bin/bash
# Prepare ranger 1.9.4 (console file manager, pure Python 3) for Maemo 5. Run INSIDE the Workshop: make -C apps/ranger build
# Nothing is compiled for ARM: the sources are copied and byte-compiled with the ARM Python 3.11 under qemu-user (needs: make -C apps/python3 build),
# because /opt is not writable for the user of the phone and a ranger without .pyc files would take many seconds to start on the Cortex-A8.
# Output: /project/build/out/ranger-$VERSION/root/opt/ranger/{lib/ranger,bin/ranger,libexec,share/doc/ranger}
set -euo pipefail

VERSION="${VERSION:-1.9.4}"
SHA256=bee308b636137b9135111fc795a57cdbb95257f2670101042ac3d7747dec32c8
URL="https://files.pythonhosted.org/packages/b6/57/c53a45928a3d6ac6a4b3d7a5d54af58a74592d4d405973d249268fc85157/ranger_fm-$VERSION.tar.gz"
PROJ=/project
DL="$PROJ/build/downloads"
SRCDIR="$PROJ/build/src"
OUT="$PROJ/build/out/ranger-$VERSION"
PY="$PROJ/build/out/python3-3.11.18/root/opt/python3"
R="$OUT/root/opt/ranger"

[ -x "$PY/bin/python3.11" ] || { echo "Missing the ARM Python 3.11, run: make -C apps/python3 build"; exit 1; }
mkdir -p "$DL" "$SRCDIR"
f="ranger_fm-$VERSION.tar.gz"
[ -s "$DL/$f" ] || curl -fL --retry 3 -o "$DL/$f" "$URL"
echo "$SHA256  $DL/$f" | sha256sum -c -
rm -rf "$SRCDIR/ranger-$VERSION" "$OUT"
mkdir -p "$SRCDIR/ranger-$VERSION" "$R/lib" "$R/bin" "$R/share/doc/ranger" "$OUT/root/usr/bin"
tar -C "$SRCDIR/ranger-$VERSION" --strip-components=1 -xzf "$DL/$f"
cd "$SRCDIR/ranger-$VERSION"

cp -a ranger "$R/lib/ranger"
# the entry script of upstream (build_scripts/ranger = ranger.py; no .py extension in the name, otherwise import ranger would load the script itself): its shebang is replaced, the wrapper /usr/bin/ranger starts it
install -m 755 build_scripts/ranger "$R/bin/ranger"
sed -i '1s|^#!.*|#!/opt/python3/bin/python3.11|' "$R/bin/ranger"
install -m 644 LICENSE AUTHORS README.md CHANGELOG.md "$R/share/doc/ranger/"
# rifle.conf for the phone (Media Player, Image Viewer, ... through D-Bus) replaces the default; hildon-open and the stand-in of file(1) are in libexec
install -m 644 "$PROJ/apps/ranger/rifle.conf" "$R/lib/ranger/config/rifle.conf"
mkdir -p "$R/libexec"
install -m 755 "$PROJ/apps/ranger/hildon-open" "$PROJ/apps/ranger/file" "$R/libexec/"
install -m 755 "$PROJ/apps/ranger/ranger" "$OUT/root/usr/bin/ranger"
chmod 755 "$R/lib/ranger/data/scope.sh"
find "$R/lib" -name '__pycache__' -prune -exec rm -rf {} +

# byte-compile with the ARM interpreter (the file names in the .pyc point to the installed place)
export QEMU_LD_PREFIX="$PROJ/sysroot" PYTHONHOME="$PY" LC_ALL=C
(cd "$R/lib" && qemu-arm "$PY/bin/python3.11" -m compileall -q -d /opt/ranger/lib ranger)
echo "== $(find "$R/lib" -name '*.pyc' | wc -l) .pyc files, $(du -sk "$R" | cut -f1) kB"
# check: the version and the import of the main modules under qemu-user
cd /
TERM=xterm TERMINFO=/usr/share/terminfo PYTHONPATH="$R/lib" PYTHONDONTWRITEBYTECODE=1 qemu-arm "$PY/bin/python3.11" -c "import ranger, ranger.core.main, ranger.gui.ui; print('ranger', ranger.__version__)"
