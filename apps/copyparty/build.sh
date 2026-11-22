#!/bin/bash
# copyparty for the N900: no compilation. Download the official single-file release (copyparty-en.py), check the SHA-256,
# unpack it once here and keep the tree for package.sh (the file unpacks itself on every start otherwise, which is slow on the phone).
#   make -C apps/copyparty build          (runs inside the Workshop)
# Output: /project/build/out/copyparty-$VERSION/tree/  (Python files, no bytecode: it is compiled by the postinst on the phone)
set -euo pipefail

VERSION="${VERSION:-1.20.26}"
SHA256="${SHA256:-3ac0786ecbfdbacb3ff194e297fa0b3cdd7152e20eb3c1ce68cbd384cd5d05f5}"   # of copyparty-en.py of v1.20.26
PROJ=/project
OUT="$PROJ/build/out/copyparty-$VERSION"
DL="$PROJ/build/downloads/copyparty-$VERSION-en.py"
URL="https://github.com/9001/copyparty/releases/download/v$VERSION/copyparty-en.py"

mkdir -p "$PROJ/build/downloads"
[ -s "$DL" ] || curl -fsSL -o "$DL" "$URL"
echo "$SHA256  $DL" | sha256sum -c - || { echo "SHA-256 differs: a new release? check it and set SHA256 (and VERSION) in apps/copyparty/Makefile and build.sh"; rm -f "$DL"; exit 1; }

rm -rf "$OUT"; mkdir -p "$OUT/home" "$OUT/tree"
# the file extracts itself into $HOME/.cache/pe-copyparty.*.0 and prints the version
HOME="$OUT/home" python3 "$DL" --version > "$OUT/version.txt" 2>&1 || { cat "$OUT/version.txt"; exit 1; }
SRC=$(ls -d "$OUT"/home/.cache/pe-copyparty.*.* | head -n 1)
cp -r "$SRC"/. "$OUT/tree/"
find "$OUT/tree" -name '__pycache__' -prune -exec rm -rf {} +
rm -rf "$OUT/home"
grep -q "copyparty v$VERSION" "$OUT/version.txt" || { echo "unexpected version:"; cat "$OUT/version.txt"; exit 1; }
test -f "$OUT/tree/copyparty/__main__.py" && test -d "$OUT/tree/j2/jinja2"
echo "== Check"
head -n 1 "$OUT/version.txt" | sed -n '/copyparty v/p'
du -sh "$OUT/tree"
