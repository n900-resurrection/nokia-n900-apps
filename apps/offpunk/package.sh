#!/bin/bash
# Package offpunk as a .deb for Maemo 5. Run INSIDE the Workshop after build.sh: make -C apps/offpunk deb
# Output: /project/build/deb/offpunk_<VERSION>-<REV>_armel.deb
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=offpunk
VERSION="${VERSION:-3.1}"
OUT="$PROJ/build/out/$PKG-$VERSION"
STAGE="$PROJ/build/deb/stage-$PKG"
[ -d "$OUT/root/opt/offpunk" ] || { echo "Missing build output in $OUT, run build.sh first (make build)"; exit 1; }

rm -rf "$STAGE"; mkdir -p "$STAGE"
cp -a "$OUT/root/." "$STAGE/"
debpack_desktop "Offpunk" "/usr/bin/offpunk" "$PROJ/apps/offpunk/icon.png"

SECTION=user/network
DEPENDS="python3.11, curl, file, less"
DISPLAY_NAME="Offpunk"
SHORT_DESC="offpunk $VERSION offline-first reader of Gemini, Gopher, web and RSS"
LONG_DESC="offpunk $VERSION: a reader for the terminal that keeps everything it has shown in a cache, so it works without the network. Type a
URL (gemini://, gopher://, https://) or a number of a link; \"offline\" works with the cache only, \"sync\" fetches the pages of your lists and
bookmarks while you have a connection, and \"help\" lists the commands. It reads feeds, too. It runs on the Python 3.11 of the package python3.11 and
has no C parts: web pages are simplified with BeautifulSoup (no lxml). The commands offpunk, ansicat (shows a file or a page in the terminal),
netcache and openk are installed. Upstream: https://offpunk.net"
MAINTAINER="elPytel (packaging of upstream offpunk by Ploum and contributors)"
debpack_build
