#!/bin/bash
# PySDL2 is pure Python (ctypes over libSDL2): nothing to compile. Download the wheel from PyPI, check its SHA-256 and unpack it.
#   make -C apps/pysdl2 build
# Output: /project/build/out/pysdl2-$VERSION/root/opt/python3/lib/python3.11/site-packages/{sdl2,PySDL2-$VERSION.dist-info}
set -euo pipefail
VERSION="${VERSION:-0.9.17}"
PROJ=/project
DL="$PROJ/build/downloads"
OUT="$PROJ/build/out/pysdl2-$VERSION"
SP="$OUT/root/opt/python3/lib/python3.11/site-packages"
case "$VERSION" in
    0.9.17) URL=https://files.pythonhosted.org/packages/5d/e2/399ea7900e7510096aeb41439e6f1540bef0bdf7e15cc2d8464e4adb71e8/PySDL2-0.9.17-py3-none-any.whl
            SHA=fe923dbf5c7b27bbc1eb2bf58abfa793f8f13fd7ae8b27b1bc2de49920bcbd41 ;;
    *) echo "Unknown version $VERSION: add its URL and SHA-256 (from https://pypi.org/pypi/PySDL2/$VERSION/json) to build.sh"; exit 1 ;;
esac
mkdir -p "$DL"
f="$DL/PySDL2-$VERSION-py3-none-any.whl"
[ -s "$f" ] || curl -fL --retry 3 -o "$f" "$URL"
echo "$SHA  $f" | sha256sum -c -
rm -rf "$OUT"; mkdir -p "$SP"
python3 -I -c "import sys, zipfile; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])" "$f" "$SP"
find "$SP" -name __pycache__ -prune -exec rm -rf {} +
python3 -I -m py_compile "$SP/sdl2/__init__.py"
find "$SP" -name __pycache__ -prune -exec rm -rf {} +
echo "pysdl2 $VERSION: $(find "$SP/sdl2" -name '*.py' | wc -l) modules, $(du -sh "$SP" | cut -f1)"
