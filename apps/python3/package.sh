#!/bin/bash
# Package Python 3.11 as a .deb for Maemo 5: make -C apps/python3 deb
# Output: /project/build/deb/python3.11_<VERSION>-<REV>_armel.deb
# The tree is in /opt/python3; /usr/bin/python3 and python3.11 are links. The system python (2.5) is not touched.
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=python3.11
VERSION="${VERSION:-3.11.18}"
OUT="$PROJ/build/out/python3-$VERSION"
STAGE="$PROJ/build/deb/stage-$PKG"
[ -x "$OUT/root/opt/python3/bin/python3.11" ] || { echo "Missing build output, run: make -C apps/python3 build"; exit 1; }

rm -rf "$STAGE"
mkdir -p "$STAGE/opt" "$STAGE/usr/bin"
cp -a "$OUT/root/opt/python3" "$STAGE/opt/"
# Slim: the static libpython (embedding only) and the second bytecode level are not needed on the phone.
rm -f "$STAGE/opt/python3/lib/libpython3.11.a"
find "$STAGE/opt/python3" -name "*.opt-1.pyc" -delete
for b in python3 python3.11; do ln -s "../../opt/python3/bin/python3.11" "$STAGE/usr/bin/$b"; done
mkdir -p "$STAGE/opt/python3/share/doc/python3"
cp "$PROJ/build/src/python3-$VERSION/LICENSE" "$STAGE/opt/python3/share/doc/python3/LICENSE"
cat > "$STAGE/opt/python3/share/doc/python3/README.Maemo" <<EOT
Python $VERSION cross-built for Maemo 5 (armel, glibc 2.5). ssl module with OpenSSL 3.5 (static, TLS 1.3),
sqlite3 (SQLite 3.50), zlib, curses (wide), no readline/ctypes/tkinter yet.
Certificates: set SSL_CERT_FILE=/opt/curl/etc/ssl/cacert.pem (package curl); the interpreter does it by itself, see sitecustomize.
pip: python3 -m ensurepip (bundled wheels), then python3 -m pip install <pure python package>.
EOT
# The CA bundle of the curl package is found without any environment variable.
mkdir -p "$STAGE/opt/python3/lib/python3.11/site-packages"
cat > "$STAGE/opt/python3/lib/python3.11/sitecustomize.py" <<'EOT'
# Default CA bundle for ssl (OpenSSL 3 is built with openssldir /opt/openssl/etc/ssl, which has no certificates).
import os
if "SSL_CERT_FILE" not in os.environ and os.path.exists("/opt/curl/etc/ssl/cacert.pem"):
    os.environ["SSL_CERT_FILE"] = "/opt/curl/etc/ssl/cacert.pem"
EOT

SECTION=user/development
DEPENDS="libc6 (>= 2.5), curl"
DISPLAY_NAME="Python 3.11"
SHORT_DESC="Python $VERSION for Maemo 5 with TLS 1.3 (ssl), sqlite3 and zlib"
LONG_DESC="Python $VERSION built for the N900 in /opt/python3 (links /usr/bin/python3, python3.11). The ssl module uses OpenSSL 3.5, certificates come from the curl package. The system Python 2.5 stays untouched."
debpack_build
