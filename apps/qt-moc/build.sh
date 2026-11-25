#!/bin/bash
# Build moc 4.7.4 (Qt meta-object compiler, GPL/LGPL) for the machine that cross-builds, inside the Workshop:
#   make -C apps/qt-moc build           (or make qt-moc)
# Output: /project/build/out/qt-moc-$VERSION/bin/moc and the licence files. Not a package for the phone: moc runs on the build host only.
#
# Why: the SDK sysroot has the Qt 4.7 headers and libraries for the phone (libqt4-dev), but its moc is an i386 scratchbox program that does not run
# here, and the moc of Qt 4.8 or 5 writes code that does not fit Qt 4.7 (the layout of QMetaObject differs). So moc is built from the Qt 4.7.4 sources:
# only qmake, the bootstrap library and moc, no GUI. Use it like this:   moc transfer.h -o moc_transfer.cpp   (run it in the directory of the header)
set -euo pipefail

VERSION="${VERSION:-4.7.4}"
SHA256="97195ebce8a46f9929fb971d9ae58326d011c4d54425389e6e936514f540221e"
PROJ=/project
DL="$PROJ/build/downloads"
SRCDIR="$PROJ/build/src"
OUT="$PROJ/build/out/qt-moc-$VERSION"
SRC="$SRCDIR/qt-$VERSION"

mkdir -p "$DL" "$SRCDIR"
f="qt-$VERSION.tar.gz"
[ -s "$DL/$f" ] || curl -fL --retry 3 -o "$DL/$f" "https://download.qt.io/archive/qt/4.7/qt-everywhere-opensource-src-$VERSION.tar.gz"
echo "$SHA256  $DL/$f" | sha256sum -c - >/dev/null || { echo "sha256 of $f differs"; exit 1; }
rm -rf "$SRC" "$OUT"
mkdir -p "$SRC" "$OUT/bin"
# only what moc needs: the sources without the demos, examples, documentation, translations, WebKit and tests
tar -C "$SRC" --strip-components=1 -xzf "$DL/$f" --exclude='*/demos' --exclude='*/examples' --exclude='*/doc' --exclude='*/translations' \
    --exclude='*/src/3rdparty/webkit' --exclude='*/tests'
cd "$SRC"
./configure -opensource -confirm-license -release -no-gui -no-opengl -no-webkit -no-phonon -no-qt3support \
    -nomake examples -nomake demos -nomake docs -nomake tools -nomake translations -silent > "$OUT/configure.log" 2>&1 || { tail -20 "$OUT/configure.log"; exit 1; }
make -C src/tools/bootstrap -j"$(nproc)" > "$OUT/make.log" 2>&1 || { tail -20 "$OUT/make.log"; exit 1; }
make -C src/tools/moc -j"$(nproc)" >> "$OUT/make.log" 2>&1 || { tail -20 "$OUT/make.log"; exit 1; }
cp bin/moc "$OUT/bin/moc"
strip "$OUT/bin/moc"
cp LICENSE.GPL3 LICENSE.LGPL LGPL_EXCEPTION.txt "$OUT/"
echo "== Check"
"$OUT/bin/moc" -v || true   # moc -v exits with 1
ls -la "$OUT/bin/moc"
