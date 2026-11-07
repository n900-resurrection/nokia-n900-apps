#!/bin/bash
# Package the built ncdu as a .deb for Maemo 5. Run INSIDE the Workshop after build.sh: make -C apps/ncdu deb
# Output: /project/build/deb/ncdu_<VERSION>-<REV>_armel.deb
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=ncdu
VERSION="${VERSION:-1.22}"
OUT="$PROJ/build/out/$PKG-$VERSION"
STAGE="$PROJ/build/deb/stage-$PKG"
[ -x "$OUT/root/opt/ncdu/bin/ncdu" ] || { echo "Missing build output in $OUT, run build.sh first (make build)"; exit 1; }

rm -rf "$STAGE"; mkdir -p "$STAGE/usr/bin"
cp -a "$OUT/root/." "$STAGE/"
ln -s "../../opt/ncdu/bin/ncdu" "$STAGE/usr/bin/ncdu"
mkdir -p "$STAGE/opt/ncdu/share/doc/ncdu"
install -m 644 "$PROJ/build/src/ncdu-$VERSION/LICENSES/MIT.txt" "$STAGE/opt/ncdu/share/doc/ncdu/LICENSE" 2>/dev/null \
    || install -m 644 "$PROJ/build/src/ncdu-$VERSION/COPYING" "$STAGE/opt/ncdu/share/doc/ncdu/LICENSE"
# The menu entry takes one command without arguments: a small launcher scans the home directory (one file system, -x).
cat > "$STAGE/opt/ncdu/bin/ncdu-home" <<'EOT'
#!/bin/sh
# ncdu on the home directory of the user (-x: stay on one file system); more directories: run ncdu / or ncdu /opt by hand
exec /opt/ncdu/bin/ncdu -x "${HOME:-/home/user}"
EOT
chmod 755 "$STAGE/opt/ncdu/bin/ncdu-home"
ln -s "../../opt/ncdu/bin/ncdu-home" "$STAGE/usr/bin/ncdu-home"
debpack_desktop "ncdu" "/usr/bin/ncdu-home" "$PROJ/apps/ncdu/icon.png"

SECTION=user/utilities
DEPENDS="libc6 (>= 2.5), libncurses5 (>= 5.7)"
DISPLAY_NAME="ncdu"
SHORT_DESC="ncdu $VERSION disk usage browser"
LONG_DESC="ncdu $VERSION for Maemo 5: shows what takes the space on a disk, directory by directory (d deletes, q quits, ? help).
The menu entry scans /home/user; in a terminal: ncdu /opt, ncdu -x / (-x stays on one file system). Built for armel, glibc 2.5; ncurses comes from the phone.
Upstream: https://dev.yorhel.nl/ncdu"
MAINTAINER="elPytel (build of upstream ncdu by Yoran Heling)"
debpack_build
