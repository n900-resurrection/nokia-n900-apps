#!/bin/bash
# Cross-build the MaeShare client (the Qt Quick 1 program /opt/maeshare/maeshare) from our fork for Maemo 5. Run INSIDE the Workshop:
#   make -C apps/maeshare build        (needs make qt-moc and the Qt 4.7 dev packages in the sysroot: make sysroot, scripts/fetch_sysroot.py libqt4-dev)
# Output: /project/build/out/maeshare-$VERSION/maeshare  and the sources it was built from (src/).
#
# What is built here: app.cpp + transfer.h + singleinstance.h of the fork and QJson. What is NOT built here: the helper `probe` (the LocalSend network core,
# its source is not published), the alias word lists, and the sharing plugin: package.sh takes them from the release package of the author.
# Compiled with maemo-g++ (static libstdc++, see maemo-toolchain), moc 4.7.4 of apps/qt-moc, headers and libraries of the sysroot (Qt 4.7.0, as on the phone).
set -euo pipefail

VERSION="${VERSION:-1.0.3}"
PROJ=/project
SR="$PROJ/sysroot"
DL="$PROJ/build/downloads"
OUT="$PROJ/build/out/maeshare-$VERSION"
MOC="$PROJ/build/out/qt-moc-4.7.4/bin/moc"

# the fork at a fixed commit, and QJson from MeeGo-Share (the network core's origin; MaeShare uses its copy), both pinned by SHA-256
FORK_COMMIT=6d35e4f39453690146d9deaee7369815f5211f13
FORK_SHA256=9ea6a997c022cab236c1bd74fbeaf359f3a3e8efaa46033fc58477dad2c95c7e
MEEGO_COMMIT=cfd985ec7fccb5262280ef0f066ec3369242c5e8
MEEGO_SHA256=cf2f8dd08f28a4f9cf7ed6c8039af4abad008d8748b0f44653788d1e6c1c54d3

[ -x "$MOC" ] || { echo "Missing moc, run: make qt-moc"; exit 1; }
[ -f "$SR/usr/include/QtDeclarative/QDeclarativeView" ] || { echo "Missing Qt 4.7 in the sysroot, run: python3 scripts/fetch_sysroot.py libqt4-dev"; exit 1; }
mkdir -p "$DL"
get() {   # get <file> <url> <sha256>
    [ -s "$DL/$1" ] || curl -fL --retry 3 -o "$DL/$1" "$2"
    echo "$3  $DL/$1" | sha256sum -c - >/dev/null || { echo "sha256 of $1 differs"; exit 1; }
}
get "maeshare-fork-${FORK_COMMIT:0:7}.tar.gz" "https://github.com/n900-resurrection/MaeShare/archive/$FORK_COMMIT.tar.gz" "$FORK_SHA256"
get "meego-share-${MEEGO_COMMIT:0:7}.tar.gz" "https://github.com/ChengChihz/MeeGo-Share/archive/$MEEGO_COMMIT.tar.gz" "$MEEGO_SHA256"

rm -rf "$OUT"
mkdir -p "$OUT/src" "$OUT/obj"
tar -C "$OUT/src" --strip-components=1 -xzf "$DL/maeshare-fork-${FORK_COMMIT:0:7}.tar.gz"
mkdir -p "$OUT/qjson"
tar -C "$OUT/qjson" --strip-components=3 -xzf "$DL/meego-share-${MEEGO_COMMIT:0:7}.tar.gz" "MeeGo-Share-$MEEGO_COMMIT/third_party/qjson"
cp "$OUT"/src/src/app/{app.cpp,transfer.h,singleinstance.h} "$OUT/"
cd "$OUT"
# moc writes the path of the header into its output: run it in the directory of the headers
"$MOC" transfer.h -o moc_transfer.cpp
"$MOC" singleinstance.h -o moc_singleinstance.cpp

INC="-I$SR/usr/include -I$SR/usr/include/QtCore -I$SR/usr/include/QtGui -I$SR/usr/include/QtNetwork -I$SR/usr/include/QtDeclarative -I$SR/usr/include/QtScript -I$SR/usr/include/QtXml -Iqjson -I."
FLAGS="-O2 -fPIC -fpermissive -w -DQT_NO_DEBUG -DQT_NETWORK_LIB -DQT_GUI_LIB -DQT_CORE_LIB -DQT_DECLARATIVE_LIB"
for f in app.cpp moc_transfer.cpp moc_singleinstance.cpp qjson/parser.cpp qjson/json_scanner.cpp qjson/json_parser.cc qjson/serializer.cpp; do
    "$PROJ/scripts/maemo-g++" $FLAGS $INC -c "$f" -o "obj/$(echo "$f" | tr / _).o"
done
"$PROJ/scripts/maemo-g++" obj/*.o -o maeshare -L"$SR/usr/lib" -lQtDeclarative -lQtGui -lQtNetwork -lQtCore -lm
arm-linux-gnueabi-strip --strip-unneeded maeshare
echo "== Check"
file maeshare | cut -c1-120
arm-linux-gnueabi-readelf -d maeshare | grep NEEDED
echo -n "Highest glibc symbol: "; arm-linux-gnueabi-objdump -T maeshare | grep -oE 'GLIBC_[0-9.]+' | sort -uV | tail -1
ls -la maeshare
