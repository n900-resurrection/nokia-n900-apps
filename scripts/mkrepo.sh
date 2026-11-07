#!/bin/bash
# Run INSIDE the Workshop (make repo): build an apt repository for Maemo 5 in /project/$REPO_DIR (default n900-repository) from the given .deb files.
#   scripts/mkrepo.sh build/deb/a.deb build/deb/b.deb ...
# Layout (suite fremantle, component main, architecture armel):
#   n900-repository/pool/main/<package>/<package>_<version>_armel.deb   (one directory per package, all its versions together; only .deb files)
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
cd "$R"
# one directory per package: first move the files of the old flat layout (pool/main/*.deb), then add the given ones
place() { local d; d="pool/main/$(dpkg-deb -f "$1" Package)"; mkdir -p "$d"; "$2" -- "$1" "$d/"; }
for f in pool/main/*.deb; do [ -e "$f" ] && place "$f" mv; done
for f in "$@"; do place "$(cd "$PROJ" && readlink -f "$f")" cp; done
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
# Output colours come from the Makefile (C_* variables, empty when the script is run by hand)
cb="${C_BOLD:-}" cg="${C_GREEN:-}" cc="${C_CYAN:-}" cy="${C_YELLOW:-}" cp="${C_PURPLE:-}" cn="${C_RESET:-}"
for f in "$@"; do
    d="$(cd "$PROJ" && readlink -f "$f")"
    echo "${cg}+${cn} ${cb}$(dpkg-deb -f "$d" Package)${cn} $(dpkg-deb -f "$d" Version)  ${cp}$(du -h "$d" | cut -f1)${cn}"
done
echo "${cg}${cb}$(grep -c '^Package:' "$B/Packages") packages${cn} in $R"
# Size overview (GitHub Pages: the published site should stay below about 1 GB, the repository below a few GB)
nd=$(find pool -name '*.deb' | wc -l)
echo "${cc}size:${cn} $(du -sh pool | cut -f1) pool ($nd .deb files in $(find pool -mindepth 2 -maxdepth 2 -type d | wc -l) directories), $(du -sh dists | cut -f1) dists, $(du -sh --exclude=.git . | cut -f1) total without git"
if git -C . rev-parse --git-dir >/dev/null 2>&1; then
    # history that is already committed (packed + loose objects); the files of this working tree come on top until they are committed
    echo "${cy}git:${cn}  $(git count-objects -vH 2>/dev/null | awk -F': ' '/^size-pack/ {p=$2} /^size:/ {l=$2} END {printf "history %s packed + %s loose objects", p, l}')"
fi
