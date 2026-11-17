#!/bin/bash
# Package mandoc as a .deb for Maemo 5. Run INSIDE the Workshop after build.sh:
#   workshop exec n900 -- bash -c '/project/apps/mandoc/package.sh'   (or: make -C apps/mandoc deb)
# Output: /project/build/deb/mandoc_<VERSION>-<REV>_armel.deb
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=mandoc
VERSION="${VERSION:-1.14.6}"
OUT="$PROJ/build/out/$PKG-$VERSION/root/opt/$PKG"
SRC="$PROJ/build/src/$PKG-$VERSION"
STAGE="$PROJ/build/deb/stage-$PKG"
[ -x "$OUT/bin/mandoc" ] || { echo "Missing $OUT/bin/mandoc, run build.sh first (make build)"; exit 1; }

rm -rf "$STAGE"
mkdir -p "$STAGE/opt/$PKG/bin" "$STAGE/opt/$PKG/share/doc/$PKG" "$STAGE/opt/$PKG/share/man" "$STAGE/usr/local/bin" "$STAGE/etc/profile.d"
# one static binary; man, apropos, whatis and makewhatis are the same program under other names (mandoc looks at argv[0])
install -m 755 "$OUT/bin/mandoc" "$STAGE/opt/$PKG/bin/mandoc"
for c in man apropos whatis makewhatis; do ln -s mandoc "$STAGE/opt/$PKG/bin/$c"; done
# /usr/local/bin is before /usr/bin in the PATH of the phone, so these win over the BusyBox `man` (which needs nroff and is left alone)
for c in mandoc man apropos whatis makewhatis mandoc-update; do ln -s "../../../opt/$PKG/bin/$c" "$STAGE/usr/local/bin/$c"; done
cp -a "$OUT/share/man/." "$STAGE/opt/$PKG/share/man/"
install -m 644 "$SRC/LICENSE" "$STAGE/opt/$PKG/share/doc/$PKG/LICENSE"
install -m 644 "$SRC/NEWS" "$STAGE/opt/$PKG/share/doc/$PKG/NEWS"
# the pages of our packages are in /opt/<package>/share/man: the search path is built from them at every login
cat > "$STAGE/etc/profile.d/mandoc.sh" <<'EOT'
# man pages of the packages in /opt/<package>/share/man (see the package mandoc)
_mp=/usr/share/man
for _d in /opt/*/share/man; do [ -d "$_d" ] && _mp="$_mp:$_d"; done
export MANPATH="$_mp"
export MANPAGER=/opt/mandoc/bin/man-pager
unset _mp _d
# A login shell has /usr/local/bin at the END of the PATH (see /etc/profile.d/sbin-path.sh), so the BusyBox `man` of /usr/bin would win: put ours first.
case ":$PATH:" in *:/opt/mandoc/bin:*) ;; *) PATH="/opt/mandoc/bin:$PATH"; export PATH ;; esac
EOT
# The pager: the BusyBox less shows the backspaces of bold and underlined text (N^HN) as they are; this strips them (the emphasis is lost, the text stays readable)
cat > "$STAGE/opt/$PKG/bin/man-pager" <<'EOT'
#!/bin/sh
# Pager of mandoc on the phone: removes the overstrike of ASCII output, then less. mandoc passes the page as a temporary FILE (not on stdin).
b=$(printf '\b')
sed "s/.$b//g" "$@" | less
EOT
chmod 755 "$STAGE/opt/$PKG/bin/man-pager"
# The index (mandoc.db) of a man page directory is what makes `man` quiet and `apropos` work. It is made by makewhatis; mandoc-update does it for
# /opt/<package>/share/man of every package. It runs after the installation of this package, and after every apt-get install/upgrade (apt hook).
cat > "$STAGE/opt/$PKG/bin/mandoc-update" <<'EOT'
#!/bin/sh
# Rebuild the man page indexes (mandoc.db) of /opt/<package>/share/man and /usr/share/man. Run as root; quiet.
for d in /opt/*/share/man /usr/share/man; do
    [ -d "$d" ] && [ -w "$d" ] && /opt/mandoc/bin/makewhatis "$d" >/dev/null 2>&1
done
exit 0
EOT
chmod 755 "$STAGE/opt/$PKG/bin/mandoc-update"
mkdir -p "$STAGE/etc/apt/apt.conf.d" "$STAGE/DEBIAN"
echo 'DPkg::Post-Invoke { "[ -x /opt/mandoc/bin/mandoc-update ] && /opt/mandoc/bin/mandoc-update || true"; };' > "$STAGE/etc/apt/apt.conf.d/50mandoc"
cat > "$STAGE/DEBIAN/postinst" <<'EOT'
#!/bin/sh
[ "$1" = configure ] && /opt/mandoc/bin/mandoc-update
exit 0
EOT
cat > "$STAGE/DEBIAN/postrm" <<'EOT'
#!/bin/sh
if [ "$1" = remove ] || [ "$1" = purge ]; then rm -f /opt/*/share/man/mandoc.db /usr/share/man/mandoc.db; fi
exit 0
EOT
chmod 755 "$STAGE/DEBIAN/postinst" "$STAGE/DEBIAN/postrm"
DEBPACK_ICON="$PROJ/apps/mandoc/icon.png"

SECTION=user/utilities
DEPENDS="libc6 (>= 2.5)"
DISPLAY_NAME="mandoc"
SHORT_DESC="man page viewer: man, apropos, whatis"
LONG_DESC="mandoc $VERSION built for Maemo 5 (armel, static). The phone has only the BusyBox man, which needs nroff and cannot show a page. This package formats man pages itself and
installs man, apropos, whatis and makewhatis in /usr/local/bin. The search path includes /opt/<package>/share/man of every package (set at login in /etc/profile.d/mandoc.sh).
Open a new terminal, then: man mandoc.
Upstream: https://mandoc.bsd.lv/ (ISC licence)"
# man pages (shown by the package mandoc)
debpack_man "$PROJ/apps/mandoc/n900.7"
debpack_build
