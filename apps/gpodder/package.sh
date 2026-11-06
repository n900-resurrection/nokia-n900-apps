#!/bin/bash
# Package gPodder 2.20.3 as a .deb for Maemo 5. Run INSIDE the Workshop after build.sh: make -C apps/gpodder deb
# Output: /project/build/deb/gpodder_2.20.3-<REV>_armel.deb  (replaces the gpodder 2.20.2 of the device)
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=gpodder
VERSION="${VERSION:-2.20.3}"
OUT="$PROJ/build/out/$PKG-$VERSION"
STAGE="$PROJ/build/deb/stage-$PKG"
[ -d "$OUT/root/usr" ] || { echo "Missing $OUT/root, run build.sh first (make build)"; exit 1; }

rm -rf "$STAGE"; mkdir -p "$STAGE"
cp -a "$OUT/root/." "$STAGE/"
mkdir -p "$STAGE/usr/share/doc/$PKG" "$STAGE/DEBIAN"
cp "$OUT/changelog" "$STAGE/usr/share/doc/$PKG/changelog.Debian"; gzip -9n "$STAGE/usr/share/doc/$PKG/changelog.Debian"
cp "$OUT/COPYING" "$STAGE/usr/share/doc/$PKG/copyright"
# upstream postinst: icon cache and the notification group of hildon-home
install -m 755 "$OUT/postinst" "$STAGE/DEBIAN/postinst"

SECTION=user/multimedia
# The same dependencies as the upstream package (python-feedparser >= 5.0.1 and python-mygpoclient >= 1.4 are on the phone).
DEPENDS="python (>= 2.5), python-gobject, python-gtk2 (>= 2.12.1-6maemo10), python-hildon (>= 0.9.0-1maemo12), python-feedparser (>= 5.0.1), python-dbus, python-osso, python-simplejson, python-mygpoclient (>= 1.4), python-conic"
DISPLAY_NAME="gPodder Podcast Client"
SHORT_DESC="A podcast aggregator for the Nokia N900"
LONG_DESC="gPodder is a podcast receiver/catcher with a specialized UI that has been optimized for Maemo 5 and the N900.
Podcasts are like short radio shows that you can download from the Internet and subscribe to like blogs or news feeds.
Version 2.20.3 \"The Odd Pod\" (YouTube download fixes) built from the upstream git tag obsolete/maemo5.
Upstream: http://gpodder.org/"
MAINTAINER="elPytel (build of upstream gPodder by Thomas Perl)"
debpack_build
