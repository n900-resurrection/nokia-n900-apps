#!/bin/bash
# Check whether a newer NSS/NSPR can replace the libraries of MicroB (see DOC/microb.md): copies the engine libraries from the phone and compares the
# symbols and ELF version nodes that libxul & co import with what the new NSS exports (.def files of the NSS source, NSPR of the host).
#   scripts/microb-nss-abi-check.sh [NSS source dir]     default: build/src/nss-3.28.6-with-nspr-4.16/nss-3.28.6
# Output: build/microb-libs/{needed,missing}.sym; "missing: 0" means that nothing the engine imports is lost.
set -euo pipefail
export LC_ALL=C
ROOT=$(cd "$(dirname "$0")/.." && pwd)
NSS=${1:-$ROOT/build/src/nss-3.28.6-with-nspr-4.16/nss-3.28.6}
DEV=${DEVICE:-n900}
W=$ROOT/build/microb-libs; mkdir -p "$W"; cd "$W"
LIBS="libnss3 libssl3 libsmime3 libnssutil3 libsoftokn3 libnssdbm3 libfreebl3 libnspr4 libplc4 libplds4"
for f in libxul.so libmozjs.so libxpcom.so $(for l in $LIBS; do echo $l.so; done); do
    [ -s "$f" ] || scp -q "$DEV:/usr/lib/microb-engine/$f" . 2>/dev/null
done
for l in $LIBS; do nm -D --defined-only $l.so | awk '$2~/^[TDBRVW]$/{print $3}' | sed 's/@.*//'; done | sort -u > stock.sym
for f in libxul.so libmozjs.so libxpcom.so libsmime3.so libssl3.so libnss3.so libsoftokn3.so; do nm -D --undefined-only $f | awk '{print $2}' | sed 's/@.*//'; done | sort -u > undef.sym
comm -12 stock.sym undef.sym > needed.sym
# .def lines: "name;", ";;name DATA ;" (data symbols are exported on Unix too)
for f in ssl/ssl.def nss/nss.def util/nssutil.def smime/smime.def softoken/softokn.def freebl/freebl.def freebl/freebl_hash.def; do
    sed -E 's/^;;//; s/;.*//; s/^[[:space:]]+//; s/[[:space:]]+$//; s/[[:space:]]+DATA$//' "$NSS/nss/lib/$f" | grep -E '^[A-Za-z_][A-Za-z0-9_]*$'
done | sort -u > new-nss.sym
nm -D --defined-only $(ls /usr/lib/*/libnspr4.so /usr/lib/*/libplc4.so /usr/lib/*/libplds4.so) | awk '$2~/^[TDBRVW]$/{print $3}' | sed 's/@.*//' | sort -u > new-nspr.sym
sort -u new-nss.sym new-nspr.sym > new.sym
comm -23 needed.sym new.sym > missing.sym
echo "imported from the stock NSS/NSPR: $(wc -l < needed.sym), missing in the new one: $(wc -l < missing.sym)"; cat missing.sym
for f in libxul.so libsmime3.so libssl3.so libnss3.so libsoftokn3.so libmozjs.so libxpcom.so; do
    readelf -V $f | sed -n '/needs section/,$p' | { grep -oE 'Name: (NSS|NSSUTIL|SOFTOKEN|SMIME|SSL|FREEBL)[A-Z]*_[0-9][0-9.]*' || true; } | sed 's/Name: //'
done | sort -u > need-vers.txt
cat "$NSS"/nss/lib/*/*.def | { grep -oE '^;\+[A-Z_]+_[0-9][0-9.]* *\{' || true; } | sed -E 's/^;\+//; s/ *\{//' | sort -u > have-vers.txt
echo "missing ELF version nodes: $(comm -23 need-vers.txt have-vers.txt | wc -l)"; comm -23 need-vers.txt have-vers.txt
