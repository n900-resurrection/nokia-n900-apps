#!/bin/bash
# Package the built htop 3.x as a .deb ("htop3") for Maemo 5. Run INSIDE the Workshop after build.sh:
#   workshop exec n900 -- bash -c 'VERSION=3.5.3 REV=1maemo1 /project/apps/htop/package.sh'
#   (or on the host: make -C apps/htop deb)
# Output: /project/build/deb/htop3_<VERSION>-<REV>_armel.deb
#
# The package is called htop3 and lives in /opt/htop3, so it can be installed next to the system
# htop 0.8.3 (package htop, /opt/maemo/usr/bin/htop), which stays untouched. /usr/bin/htop3 is a
# wrapper script, see below.
#
# Status: the package builds and can be inspected (dpkg-deb -I/-c). Installation on a device and
# the behaviour in the Application Manager are not verified yet, see TODO.md.
set -euo pipefail

APP=htop3
VERSION="${VERSION:-3.5.3}"
REV="${REV:-1maemo1}"
MAINT="${MAINTAINER:-elPytel}"
PROJ=/project
OUT="$PROJ/build/out/htop-$VERSION"
SRC="$PROJ/build/upstream/htop"
STAGE="$PROJ/build/deb/stage-$APP"
DEB="$PROJ/build/deb/${APP}_${VERSION}-${REV}_armel.deb"
TREE="$OUT/root/opt/htop3"

[ -x "$OUT/htop" ] && [ -d "$TREE" ] || { echo "Missing build output in $OUT, run build.sh first (make build)"; exit 1; }

rm -rf "$STAGE"
mkdir -p "$STAGE/DEBIAN" \
         "$STAGE/opt/$APP/bin" \
         "$STAGE/opt/$APP/share/man/man1" \
         "$STAGE/opt/$APP/share/doc/$APP" \
         "$STAGE/usr/bin" \
         "$STAGE/usr/share/applications/hildon"

# The real binary (stripped). The wrapper below is what users run.
install -m 755 "$OUT/htop" "$STAGE/opt/$APP/bin/htop"
gzip -9n -c "$TREE/share/man/man1/htop.1" > "$STAGE/opt/$APP/share/man/man1/htop.1.gz"

# htop is GPL-2+: ship the license text and say where the source and our changes are.
install -m 644 "$SRC/COPYING" "$STAGE/opt/$APP/share/doc/$APP/COPYING"
cat > "$STAGE/opt/$APP/share/doc/$APP/README.Maemo" <<EOF
htop $VERSION built for Maemo 5 (armel, glibc 2.5). Upstream: https://github.com/htop-dev/htop
Source: upstream tag $VERSION, built unchanged except for a compatibility header that defines
O_CLOEXEC (missing in the glibc 2.5 headers). ncursesw is linked statically.

/usr/bin/htop3 is a wrapper that
 - keeps htop 3 settings in \$HOME/.config/htop3/htoprc (via HTOPRC). Without HTOPRC, htop 3 would
   migrate and DELETE the ~/.htoprc of the system htop 0.8.3.
 - refreshes every 5 s (-d 50) unless you pass -d yourself. htop 3 needs about 2.4x the CPU time of
   0.8.3 on the 600 MHz Cortex-A8; a longer interval brings it back to the old level.
The system htop (/usr/bin/htop, version 0.8.3) is not modified.
EOF

# Wrapper. POSIX sh, runs under busybox ash.
cat > "$STAGE/usr/bin/htop3" <<'EOF'
#!/bin/sh
# Wrapper for htop 3.x on Maemo 5, see /opt/htop3/share/doc/htop3/README.Maemo
: "${HTOPRC:=${XDG_CONFIG_HOME:-$HOME/.config}/htop3/htoprc}"
export HTOPRC
mkdir -p "$(dirname "$HTOPRC")"
has_delay=
for a in "$@"; do
    case "$a" in -d|-d[0-9]*|--delay|--delay=*) has_delay=1 ;; esac
done
[ -n "$has_delay" ] || set -- -d 50 "$@"
exec /opt/htop3/bin/htop "$@"
EOF
chmod 755 "$STAGE/usr/bin/htop3"

# Menu launcher. Same mechanism as for WordGrinder (osso-xterm -e), verified to work there.
cat > "$STAGE/usr/share/applications/hildon/$APP.desktop" <<EOF
[Desktop Entry]
Encoding=UTF-8
Version=1.0
Type=Application
Name=htop 3
Exec=/usr/bin/osso-xterm -e /usr/bin/htop3
X-Osso-Type=application/x-executable
EOF

SIZE_KB=$(du -sk "$STAGE" | cut -f1)
cat > "$STAGE/DEBIAN/control" <<EOF
Package: $APP
Version: $VERSION-$REV
Architecture: armel
Section: user/system
Priority: optional
Installed-Size: $SIZE_KB
Depends: libc6 (>= 2.5)
Maintainer: $MAINT
XB-Maemo-Display-Name: htop 3
Description: Interactive process viewer (htop 3.x)
 htop is an interactive process viewer. This is htop 3.x built for Maemo 5, installed in
 /opt/htop3 next to the system htop 0.8.3. Start it with htop3 (refresh interval 5 s by default).
 Upstream: https://github.com/htop-dev/htop
EOF

# Uniform permissions (the container umask gives group-write): directories 755, files 644,
# executables stay 755.
chmod -R u+rwX,go+rX,go-w "$STAGE"

mkdir -p "$(dirname "$DEB")"
# gzip: the old dpkg on Maemo 5 (1.14) does not know xz. --root-owner-group: files belong to root:root.
dpkg-deb --root-owner-group -Zgzip --build "$STAGE" "$DEB"

echo "== Package"
dpkg-deb -I "$DEB"
dpkg-deb -c "$DEB"
ls -l "$DEB"
