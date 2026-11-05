#!/bin/bash
# Package the built Bash as a .deb ("bash5") for Maemo 5. Run INSIDE the Workshop after build.sh:
#   make -C apps/bash deb
# Output: /project/build/deb/bash5_<VERSION>-<REV>_armel.deb
# The package lives next to the system bash 3.2: /opt/bash5 and /usr/bin/bash5. It does not touch /bin/bash.
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=bash5
VERSION="${VERSION:-5.3}"
OUT="$PROJ/build/out/bash-$VERSION"
SRC="$PROJ/build/src/bash-$VERSION"
STAGE="$PROJ/build/deb/stage-$PKG"
[ -x "$OUT/bash" ] || { echo "Missing $OUT/bash, run build.sh first (make build)"; exit 1; }

rm -rf "$STAGE"
mkdir -p "$STAGE/opt/$PKG/bin" "$STAGE/opt/$PKG/share/doc/$PKG" "$STAGE/opt/$PKG/share/man/man1" "$STAGE/usr/bin"
install -m 755 "$OUT/bash" "$STAGE/opt/$PKG/bin/bash"
ln -s "../../opt/$PKG/bin/bash" "$STAGE/usr/bin/bash5"
install -m 644 "$SRC/COPYING" "$STAGE/opt/$PKG/share/doc/$PKG/COPYING"
gzip -9n -c "$SRC/doc/bash.1" > "$STAGE/opt/$PKG/share/man/man1/bash.1.gz"
cat > "$STAGE/opt/$PKG/share/doc/$PKG/README.Maemo" <<EOT
GNU Bash $VERSION built for Maemo 5 (armel, glibc 2.5). Upstream: https://www.gnu.org/software/bash/
Installed next to the system bash 3.2 and does not replace it. Run it as: bash5
Use in scripts: #!/usr/bin/bash5. To make it the login shell of a user, add /usr/bin/bash5 to /etc/shells.
Links dynamically against the system libc and libncurses5; readline is bundled. Built without NLS.
EOT
SECTION=user/system
DEPENDS="libc6 (>= 2.5), libncurses5 (>= 5.7)"
DISPLAY_NAME="Bash 5"
SHORT_DESC="GNU Bash $VERSION shell (next to the system bash 3.2)"
LONG_DESC="Modern Bash with associative arrays, mapfile, \${var@U}, printf %(...)T and so on.
Installed in /opt/bash5, started as bash5. The system /bin/bash 3.2 stays untouched."
debpack_build
