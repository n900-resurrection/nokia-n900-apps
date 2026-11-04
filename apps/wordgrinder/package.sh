#!/bin/bash
# Package the built WordGrinder as a .deb for Maemo 5. Run INSIDE the Workshop after build.sh:
#   workshop exec n900 -- bash -c 'VERSION=0.8 REV=1maemo1 /project/apps/wordgrinder/package.sh'
#   (or on the host: make -C apps/wordgrinder deb)
# Output: /project/build/deb/wordgrinder_<VERSION>-<REV>_armel.deb
#
# Status: verified on a real N900 (2026-11-04): install, dpkg -L, ldd, launch from the menu.
# Not verified: installation through the Application Manager, see DOC/packaging.md, section 4.
set -euo pipefail

APP=wordgrinder
VERSION="${VERSION:-0.8}"
REV="${REV:-1maemo1}"
MAINT="${MAINTAINER:-elPytel}"
PROJ=/project
OUT="$PROJ/build/out/$APP-$VERSION"
SRC="$PROJ/build/upstream/$APP"
STAGE="$PROJ/build/deb/stage-$APP"
DEB="$PROJ/build/deb/${APP}_${VERSION}-${REV}_armel.deb"

[ -x "$OUT/$APP" ] || { echo "Missing $OUT/$APP, run build.sh first (make build)"; exit 1; }

rm -rf "$STAGE"
mkdir -p "$STAGE/DEBIAN" \
         "$STAGE/opt/$APP/bin" \
         "$STAGE/opt/$APP/share/doc/$APP" \
         "$STAGE/opt/$APP/share/man/man1" \
         "$STAGE/usr/bin" \
         "$STAGE/usr/share/applications/hildon"

# The application lives in /opt (a bind mount of /home/opt on the device; the root partition is small).
install -m 755 "$OUT/$APP" "$STAGE/opt/$APP/bin/$APP"
install -m 644 "$SRC/README.wg" "$STAGE/opt/$APP/share/doc/$APP/README.wg"
if [ -d "$SRC/licenses" ]; then
    cp -r "$SRC/licenses" "$STAGE/opt/$APP/share/doc/$APP/licenses"
fi
gzip -9n -c "$SRC/wordgrinder.man" > "$STAGE/opt/$APP/share/man/man1/$APP.1.gz"

# Link in PATH (relative, so it works regardless of the root it is installed under)
ln -s "../../opt/$APP/bin/$APP" "$STAGE/usr/bin/$APP"

# Menu launcher. A console application needs a terminal.
cat > "$STAGE/usr/share/applications/hildon/$APP.desktop" <<EOF
[Desktop Entry]
Encoding=UTF-8
Version=1.0
Type=Application
Name=WordGrinder
Exec=/usr/bin/osso-xterm -e /usr/bin/$APP
X-Osso-Type=application/x-executable
EOF
chmod 644 "$STAGE/usr/share/applications/hildon/$APP.desktop"

SIZE_KB=$(du -sk "$STAGE" | cut -f1)
cat > "$STAGE/DEBIAN/control" <<EOF
Package: $APP
Version: $VERSION-$REV
Architecture: armel
Section: user/office
Priority: optional
Installed-Size: $SIZE_KB
Depends: libc6 (>= 2.5), zlib1g
Maintainer: $MAINT
XB-Maemo-Display-Name: WordGrinder
Description: Console word processor
 WordGrinder is a simple, Unicode-aware word processor that runs on the console.
 Built for Maemo 5 (armel, glibc 2.5) with ncursesw linked statically.
 Upstream: https://github.com/davidgiven/wordgrinder
EOF

# Uniform permissions (the container umask gives group-write): directories 755, files 644,
# executables stay 755.
chmod -R u+rwX,go+rX,go-w "$STAGE"

mkdir -p "$(dirname "$DEB")"
# gzip: the old dpkg on Maemo 5 (1.14) does not know xz. --root-owner-group: files belong to root:root.
dpkg-deb --root-owner-group -Zgzip --build "$STAGE" "$DEB"

echo "== Package"
dpkg-deb -I "$DEB"
dpkg-deb -c "$DEB"
ls -l "$DEB"
