#!/bin/bash
# Shared helpers for the package.sh scripts in apps/<app>/. Source it, do not run it:
#   . /project/scripts/debpack.sh
#
# A package.sh prepares the file tree in $STAGE, sets the variables below and calls debpack_build.
#
# Variables for debpack_build:
#   PKG           package name
#   VERSION       upstream version
#   REV           package revision, e.g. 1maemo1 (default)
#   EPOCH         optional epoch (a number): Version becomes EPOCH:VERSION-REV and sorts above every version without it or with a smaller epoch.
#                 Needed when the package has the name of a community package whose version has an epoch (git, mc, openssh: Extras has 1:...);
#                 without it apt and the Fast Application Manager offer that older package as an "update". An epoch can never be dropped again.
#   STAGE         directory with the files of the package (without DEBIAN/)
#   SECTION       Maemo section, e.g. user/utilities
#   RECOMMENDS    optional, packages that are installed with it by default but are not required (the Recommends field)
#   PROVIDES, CONFLICTS, REPLACES   optional, the fields of that name (a package that takes the place of others: openssh)
#   DEPENDS       Depends: line, e.g. "libc6 (>= 2.5), libncurses5 (>= 5.7)"
#   DISPLAY_NAME  name shown by the Application Manager
#   SHORT_DESC    one-line description
#   LONG_DESC     longer description (several lines allowed)
#   MAINTAINER    optional, default elPytel
#
# Output: /project/build/deb/<PKG>_<VERSION>-<REV>_armel.deb   (the file name has no epoch)

PROJ="${PROJ:-/project}"

# debpack_desktop <name> <exec> [icon.png]
# Adds a Hildon menu entry that starts a console program in the terminal (osso-xterm -e <exec>).
# Only a single command without arguments is verified to work with osso-xterm -e (see WordGrinder).
# With an icon (a square PNG, 48 px or larger): it is installed as hicolor/48x48 and 64x64 apps/$PKG.png, the entry gets Icon=$PKG and
# debpack_build adds XB-Maemo-Icon-26 (the icon of the Application Manager list). Needs ImageMagick (convert) in the Workshop.
debpack_desktop() {
    local name=$1 exec_cmd=$2 icon=${3:-}
    mkdir -p "$STAGE/usr/share/applications/hildon"
    cat > "$STAGE/usr/share/applications/hildon/$PKG.desktop" <<EOF
[Desktop Entry]
Encoding=UTF-8
Version=1.0
Type=Application
Name=$name
Exec=/usr/bin/osso-xterm -e $exec_cmd
X-Osso-Type=application/x-executable
EOF
    if [ -n "$icon" ]; then
        [ -s "$icon" ] || { echo "debpack_desktop: missing icon $icon"; return 1; }
        local sz
        for sz in 48 64; do
            mkdir -p "$STAGE/usr/share/icons/hicolor/${sz}x${sz}/apps"
            convert "$icon" -resize "${sz}x${sz}" "$STAGE/usr/share/icons/hicolor/${sz}x${sz}/apps/$PKG.png"
        done
        echo "Icon=$PKG" >> "$STAGE/usr/share/applications/hildon/$PKG.desktop"
        DEBPACK_ICON=$icon
    fi
}

# debpack_man <file>...: install man pages (roff source, .gz allowed) as /opt/$PKG/share/man/man<N>/<name>.<N>.gz, N from the extension.
# The package mandoc shows them (its profile script puts every /opt/*/share/man on MANPATH). A missing file is an error: the page was expected.
debpack_man() {
    local f base sec dir
    for f in "$@"; do
        [ -s "$f" ] || { echo "debpack_man: missing $f" >&2; return 1; }
        base=$(basename "$f" .gz); sec=${base##*.}; sec=${sec:0:1}
        dir="$STAGE/opt/$PKG/share/man/man$sec"; mkdir -p "$dir"
        case $f in *.gz) cp "$f" "$dir/$base.gz" ;; *) gzip -9n -c "$f" > "$dir/$base.gz" ;; esac
    done
}

# debpack_man_download <url> [name.N]: a man page that is not in the sources we build from: downloaded once (build/downloads/man-<name>), then as debpack_man.
debpack_man_download() {
    local url=$1 name=${2:-$(basename "$1")} dl="$PROJ/build/downloads" tmp
    mkdir -p "$dl"
    [ -s "$dl/man-$PKG-$name" ] || curl -fsSL --retry 3 -o "$dl/man-$PKG-$name" "$url"
    tmp=$(mktemp -d); cp "$dl/man-$PKG-$name" "$tmp/$name"; debpack_man "$tmp/$name"; rm -rf "$tmp"
}

# debpack_build: write DEBIAN/control, normalise permissions and build the .deb.
debpack_build() {
    : "${PKG:?}" "${VERSION:?}" "${STAGE:?}" "${SECTION:?}" "${DEPENDS:?}" "${DISPLAY_NAME:?}" "${SHORT_DESC:?}" "${LONG_DESC:?}"
    REV="${REV:-1maemo1}"
    # a package without an icon of its own gets the one of the catalogue (scripts/make-pkg-icons.sh): shown by the Application Manager and the web site
    if [ -z "${DEBPACK_ICON:-}" ] && [ -s "$PROJ/icons/packages/$PKG.png" ]; then DEBPACK_ICON="$PROJ/icons/packages/$PKG.png"; fi
    local maint="${MAINTAINER:-elPytel}"
    local deb="$PROJ/build/deb/${PKG}_${VERSION}-${REV}_armel.deb"

    mkdir -p "$STAGE/DEBIAN"
    local size_kb
    # Installed-Size from the sizes of the files (rounded up to 4 kB blocks), not from `du`: du counts what the file system of the build has allocated,
    # which differs between two builds of the same package and would make the .deb not reproducible.
    size_kb=$(find "$STAGE" -type f -not -path "$STAGE/DEBIAN/*" -printf '%s\n' | awk '{ s += int(($1 + 4095) / 4096) * 4 } END { print s + 0 }')
    {
        echo "Package: $PKG"
        echo "Version: ${EPOCH:+$EPOCH:}$VERSION-$REV"
        echo "Architecture: armel"
        echo "Section: $SECTION"
        echo "Priority: optional"
        echo "Installed-Size: $size_kb"
        echo "Depends: $DEPENDS"
        [ -n "${RECOMMENDS:-}" ] && echo "Recommends: $RECOMMENDS"
        [ -n "${PROVIDES:-}" ] && echo "Provides: $PROVIDES"
        [ -n "${CONFLICTS:-}" ] && echo "Conflicts: $CONFLICTS"
        [ -n "${REPLACES:-}" ] && echo "Replaces: $REPLACES"
        echo "Maintainer: $maint"
        echo "XB-Maemo-Display-Name: $DISPLAY_NAME"
        if [ -n "${DEBPACK_ICON:-}" ]; then
            # the icon of the Application Manager list: 26x26 PNG in base64, continuation lines start with one space
            echo "XB-Maemo-Icon-26:"
            convert "$DEBPACK_ICON" -resize 26x26 -strip -define png:exclude-chunk=tIME,tEXt,zTXt,iTXt +set date:create +set date:modify +set date:timestamp png:- | base64 -w 0 | fold -w 76 | sed 's/^/ /'
            echo
        fi
        echo "Description: $SHORT_DESC"
        # Continuation lines of the description start with one space.
        printf '%s\n' "$LONG_DESC" | sed 's/^/ /'
    } > "$STAGE/DEBIAN/control"

    # Uniform permissions (the container umask gives group-write): directories 755, files 644,
    # executables stay 755.
    chmod -R u+rwX,go+rX,go-w "$STAGE"

    # Reproducible package: the same input gives the same bytes, so a rebuild does not change the .deb file in the git repository of the apt repo
    # (and the packages that did not change are not committed again). All times in the stage are set to a fixed date, the ar header takes it from
    # SOURCE_DATE_EPOCH. The date is a fixed one on purpose (not the date of the build or of a commit).
    # ImageMagick writes the time of the conversion into every PNG that `convert` made (the chunk tIME and the properties date:create, date:modify,
    # date:timestamp): remove it
    # from the PNG files of the package (only those that have it; the picture stays the same).
    find "$STAGE" -type f -name '*.png' -print0 | while IFS= read -r -d '' png; do
        if grep -qa -e 'date:' -e 'tIME' "$png"; then
            mogrify -strip -define png:exclude-chunk=tIME,tEXt,zTXt,iTXt +set date:create +set date:modify +set date:timestamp "$png"
        fi
    done
    export SOURCE_DATE_EPOCH="${DEBPACK_EPOCH:-1767225600}"          # 2026-01-01 00:00:00 UTC
    find "$STAGE" -exec touch -h -d "@$SOURCE_DATE_EPOCH" {} +
    mkdir -p "$(dirname "$deb")"
    # gzip: the old dpkg on Maemo 5 (1.14) does not know xz. --root-owner-group: files belong to root:root.
    dpkg-deb --root-owner-group -Zgzip --build "$STAGE" "$deb"

    echo "== Package"
    dpkg-deb -I "$deb"
    # Long listings (git has hundreds of symlinks) are summarised instead of printed.
    local listing count
    listing=$(dpkg-deb -c "$deb" | grep -v '/$')
    count=$(printf '%s\n' "$listing" | wc -l)
    if [ "$count" -gt 40 ]; then
        echo "files: $count, of which symlinks: $(printf '%s\n' "$listing" | grep -c '^l')"
    else
        printf '%s\n' "$listing"
    fi
    ls -l "$deb"
}
