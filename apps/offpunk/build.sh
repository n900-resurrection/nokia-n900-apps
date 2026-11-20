#!/bin/bash
# Prepare offpunk (Gemini/Gopher/web/RSS reader, pure Python 3) for Maemo 5. Run INSIDE the Workshop: make -C apps/offpunk build
# Nothing is compiled for ARM: the wheels of offpunk and of its pure Python libraries (SHA256SUMS lists them, they are checked) are unpacked into one
# folder and byte-compiled with the ARM Python 3.11 under qemu-user (needs: make -C apps/python3 build), because /opt is not writable for the user of the
# phone and a program without .pyc files would take many seconds to start on the Cortex-A8.
# Left out on purpose: lxml + readability-lxml (C extensions: web pages are cleaned up by BeautifulSoup only), cryptography (the certificates of Gemini
# are then checked in a simpler way) and setproctitle (C extension, cosmetic).
# Output: /project/build/out/offpunk-$VERSION/root/opt/offpunk/{lib,share/doc/offpunk} and root/usr/bin/<commands>
set -euo pipefail

VERSION="${VERSION:-3.1}"
PROJ=/project
APP="$PROJ/apps/offpunk"
DL="$PROJ/build/downloads/offpunk"
OUT="$PROJ/build/out/offpunk-$VERSION"
PY="$PROJ/build/out/python3-3.11.18/root/opt/python3"
R="$OUT/root/opt/offpunk"

[ -x "$PY/bin/python3.11" ] || { echo "Missing the ARM Python 3.11, run: make -C apps/python3 build"; exit 1; }
mkdir -p "$DL"
# the files: pure Python wheels from PyPI
if [ "$(cd "$DL" && sha256sum -c "$APP/SHA256SUMS" 2>/dev/null | grep -c ': OK$')" -lt "$(wc -l < "$APP/SHA256SUMS")" ]; then
    (cd "$DL" && python3 -m pip download --no-deps --only-binary :all: --platform any --python-version 3.11 --implementation py -q -d . \
        "offpunk==$VERSION" requests urllib3 idna certifi charset-normalizer beautifulsoup4 soupsieve chardet feedparser feedparser-sgmllib typing_extensions)
fi
(cd "$DL" && sha256sum -c "$APP/SHA256SUMS")

rm -rf "$OUT"; mkdir -p "$R/lib" "$R/share/doc/offpunk" "$OUT/root/usr/bin"
for w in "$DL"/*.whl; do python3 -m zipfile -e "$w" "$R/lib"; done      # (no unzip in the Workshop)
# the licences of the parts, the entry points of offpunk are written as wrappers below
for d in "$R"/lib/*.dist-info; do
    n=$(basename "$d" .dist-info)
    for f in "$d"/licenses/LICENSE* "$d"/licenses/COPYING* "$d"/LICENSE* "$d"/COPYING*; do
        [ -f "$f" ] && { cp "$f" "$R/share/doc/offpunk/LICENSE-$n"; break; }
    done
done
rm -rf "$R"/lib/*.dist-info/RECORD "$R"/lib/bin
find "$R/lib" -name '__pycache__' -prune -exec rm -rf {} +

# the commands: wrappers that set the library folder and the certificates (the CA bundle of the package curl) and start the ARM Python of the phone
mk_cmd() {   # name module function
    cat > "$OUT/root/usr/bin/$1" <<EOW
#!/bin/sh
# $1 of the package offpunk (see /opt/offpunk/share/doc/offpunk/README.Maemo)
PYTHONPATH=/opt/offpunk/lib\${PYTHONPATH:+:\$PYTHONPATH}
PATH=/opt/less/bin:\$PATH            # the GNU less of the package less (the BusyBox pager has no --version, which offpunk asks for)
SSL_CERT_FILE=\${SSL_CERT_FILE:-/opt/curl/etc/ssl/cacert.pem}
REQUESTS_CA_BUNDLE=\${REQUESTS_CA_BUNDLE:-\$SSL_CERT_FILE}
export PATH PYTHONPATH SSL_CERT_FILE REQUESTS_CA_BUNDLE
exec /opt/python3/bin/python3.11 -c "import sys; sys.argv[0] = '$1'; import $2; sys.exit($2.$3())" "\$@"
EOW
    chmod 755 "$OUT/root/usr/bin/$1"
}
mk_cmd offpunk offpunk main
mk_cmd ansicat ansicat main
mk_cmd netcache netcache main
mk_cmd openk openk main
cp "$APP/README.Maemo" "$R/share/doc/offpunk/README.Maemo"

# byte-compile with the ARM interpreter (the file names in the .pyc point to the installed place)
export QEMU_LD_PREFIX="$PROJ/sysroot" PYTHONHOME="$PY" LC_ALL=C
(cd "$R/lib" && qemu-arm "$PY/bin/python3.11" -m compileall -q -d /opt/offpunk/lib . >/dev/null)
echo "== $(find "$R/lib" -name '*.pyc' | wc -l) .pyc files, $(du -sk "$R" | cut -f1) kB"
# check: the imports under qemu-user
cd /
PYTHONPATH="$R/lib" PYTHONDONTWRITEBYTECODE=1 qemu-arm "$PY/bin/python3.11" -c "
import offpunk, ansicat, netcache, requests, bs4, feedparser, chardet
print('offpunk', offpunk.__version__ if hasattr(offpunk, '__version__') else 'imported')"
