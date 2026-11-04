#!/bin/bash
# Zabalí sestavený WordGrinder do .deb pro Maemo 5. Spouští se UVNITŘ Workshopu po build.sh:
#   workshop exec n900 -- bash -c 'VERSION=0.8 REV=1maemo1 /project/apps/wordgrinder/package.sh'
#   (nebo na hostiteli: make -C apps/wordgrinder deb)
# Výstup: /project/build/deb/wordgrinder_<VERSION>-<REV>_armel.deb
#
# Stav: balíček se vytvoří a jde zkontrolovat (dpkg-deb -I/-c). Chování Application Manageru
# a pole specifická pro Maemo 5 NEJSOU ověřená, viz DOC/packaging.md, sekce 4.
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

[ -x "$OUT/$APP" ] || { echo "Chybí $OUT/$APP, spusť nejdřív build.sh (make build)"; exit 1; }

rm -rf "$STAGE"
mkdir -p "$STAGE/DEBIAN" \
         "$STAGE/opt/$APP/bin" \
         "$STAGE/opt/$APP/share/doc/$APP" \
         "$STAGE/opt/$APP/share/man/man1" \
         "$STAGE/usr/bin" \
         "$STAGE/usr/share/applications/hildon"

# Aplikace žije v /opt (na telefonu bind mount z /home/opt, kořenový oddíl je malý).
install -m 755 "$OUT/$APP" "$STAGE/opt/$APP/bin/$APP"
install -m 644 "$SRC/README.wg" "$STAGE/opt/$APP/share/doc/$APP/README.wg"
if [ -d "$SRC/licenses" ]; then
    cp -r "$SRC/licenses" "$STAGE/opt/$APP/share/doc/$APP/licenses"
fi
gzip -9n -c "$SRC/wordgrinder.man" > "$STAGE/opt/$APP/share/man/man1/$APP.1.gz"

# Odkaz v PATH (relativní, aby fungoval i při jiném kořeni)
ln -s "../../opt/$APP/bin/$APP" "$STAGE/usr/bin/$APP"

# Spouštěč v menu. Konzolová aplikace potřebuje terminál. [ověřit] parametry osso-xterm na zařízení.
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

# Jednotná práva (umask v kontejneru dává group-write): adresáře 755, soubory 644, spustitelné zůstanou 755.
chmod -R u+rwX,go+rX,go-w "$STAGE"

mkdir -p "$(dirname "$DEB")"
# gzip: staré dpkg na Maemo 5 (1.14) nezná xz. --root-owner-group: soubory patří root:root.
dpkg-deb --root-owner-group -Zgzip --build "$STAGE" "$DEB"

echo "== Balíček"
dpkg-deb -I "$DEB"
dpkg-deb -c "$DEB"
ls -l "$DEB"
