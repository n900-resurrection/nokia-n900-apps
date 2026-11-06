#!/bin/bash
# Run INSIDE the Workshop (make repo): build an apt repository for Maemo 5 in /project/$REPO_DIR (default n900-repository) from the given .deb files.
#   scripts/mkrepo.sh build/deb/a.deb build/deb/b.deb ...
# Layout (suite fremantle, component main, architecture armel):
#   n900-repository/pool/main/<file>.deb
#   n900-repository/dists/fremantle/main/binary-armel/Packages, Packages.gz
#   n900-repository/dists/fremantle/Release   (MD5Sum, SHA1 and SHA256: the apt 0.7 of the phone verifies only MD5/SHA1)
# The old apt of Fremantle reads only Packages.gz (no xz) and no InRelease; signing (Release.gpg) is in TODO.md.
# pool/ is kept: the given .deb files are added to it (a file of the same name is replaced), so older versions of every package stay in
# the repository for downgrades (apt-get install pkg=version). Only dists/ is regenerated, from everything in pool/ (dpkg-scanpackages -m lists all
# versions; apt installs the highest). Nothing is pruned for now; to drop a package or an old version, delete its file from pool/main by hand.
set -euo pipefail
PROJ=/project
R="$PROJ/${REPO_DIR:-n900-repository}"
SUITE="${SUITE:-fremantle}"
[ $# -gt 0 ] || { echo "usage: $0 file.deb ..."; exit 1; }
B="dists/$SUITE/main/binary-armel"
mkdir -p "$R"
rm -rf "$R/dists"
mkdir -p "$R/pool/main" "$R/$B"
cp -- "$@" "$R/pool/main/"
cd "$R"
dpkg-scanpackages -m --arch armel pool 2>"$PROJ/build/mkrepo.log" > "$B/Packages"
gzip -9nc "$B/Packages" > "$B/Packages.gz"
{
    echo "Origin: N900 community packages"
    echo "Label: N900"
    echo "Suite: $SUITE"
    echo "Codename: $SUITE"
    echo "Date: $(date -Ru)"
    echo "Architectures: armel"
    echo "Components: main"
    echo "Description: Modern software for the Nokia N900 (Maemo 5)"
    for h in MD5Sum:md5sum SHA1:sha1sum SHA256:sha256sum; do
        echo "${h%%:*}:"
        for f in main/binary-armel/Packages main/binary-armel/Packages.gz; do
            printf ' %s %16d %s\n' "$(cd dists/$SUITE && ${h##*:} "$f" | cut -d' ' -f1)" "$(stat -c%s "dists/$SUITE/$f")" "$f"
        done
    done
} > "dists/$SUITE/Release"
echo "$(grep -c '^Package:' "$B/Packages") packages in $R"
