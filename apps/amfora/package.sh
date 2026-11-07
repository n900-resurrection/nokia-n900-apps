#!/bin/bash
# Package the built amfora as a .deb for Maemo 5. Run INSIDE the Workshop after build.sh: make -C apps/amfora deb
# Output: /project/build/deb/amfora_<VERSION>-<REV>_armel.deb   (menu entry "Amfora" starts it in the terminal)
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=amfora
VERSION="${VERSION:-1.11.0}"
OUT="$PROJ/build/out/$PKG-$VERSION"
STAGE="$PROJ/build/deb/stage-$PKG"
[ -x "$OUT/amfora" ] || { echo "Missing build output in $OUT, run build.sh first (make build)"; exit 1; }

rm -rf "$STAGE"; mkdir -p "$STAGE/opt/amfora/bin" "$STAGE/opt/amfora/share/doc/amfora" "$STAGE/usr/bin"
install -m 755 "$OUT/amfora" "$STAGE/opt/amfora/bin/amfora"
ln -s "../../opt/amfora/bin/amfora" "$STAGE/usr/bin/amfora"
install -m 644 "$OUT/LICENSE" "$STAGE/opt/amfora/share/doc/amfora/LICENSE"
debpack_desktop "Amfora" "/usr/bin/amfora" "$PROJ/apps/amfora/icon.png"

SECTION=user/network
DEPENDS="libc6"
DISPLAY_NAME="Amfora"
SHORT_DESC="amfora $VERSION browser for Gemini space"
LONG_DESC="Amfora $VERSION: a terminal browser for the Gemini protocol (small, text-only pages over TLS 1.3, no ads, no scripts). Start it from the menu, press Ctrl-L
or type a gemini:// address (for example gemini://geminiprotocol.net), Tab/Enter follow links, q quits, ? shows the keys. Servers are trusted on first use (TOFU).
Built for Maemo 5 with Go (static). Upstream: https://github.com/makew0rld/amfora"
MAINTAINER="elPytel (build of upstream amfora by makeworld and contributors)"
debpack_build
