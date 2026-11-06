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
#   STAGE         directory with the files of the package (without DEBIAN/)
#   SECTION       Maemo section, e.g. user/utilities
#   DEPENDS       Depends: line, e.g. "libc6 (>= 2.5), libncurses5 (>= 5.7)"
#   DISPLAY_NAME  name shown by the Application Manager
#   SHORT_DESC    one-line description
#   LONG_DESC     longer description (several lines allowed)
#   MAINTAINER    optional, default elPytel
#
# Output: /project/build/deb/<PKG>_<VERSION>-<REV>_armel.deb

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

# debpack_build: write DEBIAN/control, normalise permissions and build the .deb.
debpack_build() {
    : "${PKG:?}" "${VERSION:?}" "${STAGE:?}" "${SECTION:?}" "${DEPENDS:?}" "${DISPLAY_NAME:?}" "${SHORT_DESC:?}" "${LONG_DESC:?}"
    REV="${REV:-1maemo1}"
    local maint="${MAINTAINER:-elPytel}"
    local deb="$PROJ/build/deb/${PKG}_${VERSION}-${REV}_armel.deb"

    mkdir -p "$STAGE/DEBIAN"
    local size_kb
    size_kb=$(du -sk "$STAGE" | cut -f1)
    {
        echo "Package: $PKG"
        echo "Version: $VERSION-$REV"
        echo "Architecture: armel"
        echo "Section: $SECTION"
        echo "Priority: optional"
        echo "Installed-Size: $size_kb"
        echo "Depends: $DEPENDS"
        echo "Maintainer: $maint"
        echo "XB-Maemo-Display-Name: $DISPLAY_NAME"
        if [ -n "${DEBPACK_ICON:-}" ]; then
            # the icon of the Application Manager list: 26x26 PNG in base64, continuation lines start with one space
            echo "XB-Maemo-Icon-26:"
            convert "$DEBPACK_ICON" -resize 26x26 png:- | base64 -w 0 | fold -w 76 | sed 's/^/ /'
            echo
        fi
        echo "Description: $SHORT_DESC"
        # Continuation lines of the description start with one space.
        printf '%s\n' "$LONG_DESC" | sed 's/^/ /'
    } > "$STAGE/DEBIAN/control"

    # Uniform permissions (the container umask gives group-write): directories 755, files 644,
    # executables stay 755.
    chmod -R u+rwX,go+rX,go-w "$STAGE"

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
