#!/bin/bash
# Package the built cointop as a .deb for Maemo 5. Run INSIDE the Workshop after build.sh: make -C apps/cointop deb
# Output: /project/build/deb/cointop_<VERSION>-<REV>_armel.deb   (the menu entry opens it in the terminal)
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=cointop
VERSION="${VERSION:-1.6.10}"
OUT="$PROJ/build/out/$PKG-$VERSION"
SRC=$(ls -d "$PROJ"/build/go/gopath/pkg/mod/github.com/cointop-sh/cointop@v$VERSION | head -1)
STAGE="$PROJ/build/deb/stage-$PKG"
[ -x "$OUT/cointop" ] || { echo "Missing build output in $OUT, run build.sh first (make build)"; exit 1; }

rm -rf "$STAGE"; mkdir -p "$STAGE/opt/cointop/bin" "$STAGE/opt/cointop/share/doc/cointop" "$STAGE/usr/bin"
install -m 755 "$OUT/cointop" "$STAGE/opt/cointop/bin/cointop"
# /usr/bin/cointop: Go finds no certificates on the phone, so the CA bundle of the package curl is given
cat > "$STAGE/usr/bin/cointop" <<'EOW'
#!/bin/sh
# cointop of the package cointop: Go reads the certificates from SSL_CERT_FILE (the CA bundle of the package curl)
SSL_CERT_FILE=${SSL_CERT_FILE:-/opt/curl/etc/ssl/cacert.pem}
export SSL_CERT_FILE
exec /opt/cointop/bin/cointop "$@"
EOW
chmod 755 "$STAGE/usr/bin/cointop"
install -m 644 "$SRC/LICENSE" "$STAGE/opt/cointop/share/doc/cointop/LICENSE"
cat > "$STAGE/opt/cointop/share/doc/cointop/README.Maemo" <<EOT
cointop $VERSION (https://github.com/cointop-sh/cointop, Apache-2.0) built for Maemo 5 by apps/cointop of the N900 project: Go, static binary.
The upstream repository was archived in 2024 (the last release is 1.6.10); it still works with the free CoinGecko API, which limits the number
of calls per minute: right after the start it may answer "429 rate limit" (the table is empty); wait a minute and press r to refresh.
Keys: arrows or h j k l move, Enter shows the chart of a coin, space makes a favourite, / searches, ? shows help, q quits.
The data come from api.coingecko.com over HTTPS (the certificates of the package curl). Configuration: ~/.config/cointop/config.toml.
EOT
debpack_desktop "Crypto (cointop)" "/usr/bin/cointop" "$PROJ/apps/cointop/icon.png"

SECTION=user/utilities
DEPENDS="libc6, curl"
DISPLAY_NAME="cointop (crypto prices)"
SHORT_DESC="cointop $VERSION cryptocurrency prices in the terminal"
LONG_DESC="cointop $VERSION: a table of the cryptocurrencies with their price, change and market capitalisation, charts, favourites and a portfolio
(holdings), for the terminal. The data come from the free CoinGecko API over HTTPS, which limits the calls per minute (wait and refresh with r).
Built for Maemo 5 with Go as a static binary (11 MB). The upstream repository is archived (2024), the last release still works.
Upstream: https://github.com/cointop-sh/cointop"
MAINTAINER="elPytel (build of upstream cointop by Miguel Mota and contributors)"
debpack_build
