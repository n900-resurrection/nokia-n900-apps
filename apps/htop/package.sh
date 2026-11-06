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
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=htop3
VERSION="${VERSION:-3.5.3}"
OUT="$PROJ/build/out/htop-$VERSION"
SRC="$PROJ/build/upstream/htop"
STAGE="$PROJ/build/deb/stage-$PKG"
TREE="$OUT/root/opt/htop3"

[ -x "$OUT/htop" ] && [ -d "$TREE" ] || { echo "Missing build output in $OUT, run build.sh first (make build)"; exit 1; }

rm -rf "$STAGE"
mkdir -p "$STAGE/opt/$PKG/bin" \
         "$STAGE/opt/$PKG/share/man/man1" \
         "$STAGE/opt/$PKG/share/doc/$PKG" \
         "$STAGE/usr/bin" \
         "$STAGE/usr/share/applications/hildon"

# The real binary (stripped). The wrapper below is what users run.
install -m 755 "$OUT/htop" "$STAGE/opt/$PKG/bin/htop"
gzip -9n -c "$TREE/share/man/man1/htop.1" > "$STAGE/opt/$PKG/share/man/man1/htop.1.gz"

# htop is GPL-2+: ship the license text and say where the source and our changes are.
install -m 644 "$SRC/COPYING" "$STAGE/opt/$PKG/share/doc/$PKG/COPYING"
cat > "$STAGE/opt/$PKG/share/doc/$PKG/README.Maemo" <<EOF
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
debpack_desktop "htop 3" "/usr/bin/htop3" "$PROJ/build/upstream/htop/htop.png"

SECTION=user/system
DEPENDS="libc6 (>= 2.5)"
DISPLAY_NAME="htop 3"
SHORT_DESC="Interactive process viewer (htop 3.x)"
LONG_DESC="htop is an interactive process viewer. This is htop 3.x built for Maemo 5, installed in
/opt/htop3 next to the system htop 0.8.3. Start it with htop3 (refresh interval 5 s by default).
Upstream: https://github.com/htop-dev/htop"
debpack_build
