#!/bin/bash
# Package the built mc as a .deb for Maemo 5. Run INSIDE the Workshop after build.sh: make -C apps/mc deb
# Output: /project/build/deb/mc_<VERSION>-<REV>_armel.deb   (a command line tool: no menu entry)
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=mc
VERSION="${VERSION:-4.8.33}"
OUT="$PROJ/build/out/$PKG-$VERSION"
STAGE="$PROJ/build/deb/stage-$PKG"
[ -x "$OUT/mc" ] || { echo "Missing build output in $OUT, run build.sh first (make build)"; exit 1; }

rm -rf "$STAGE"; mkdir -p "$STAGE/usr/bin" "$STAGE/opt/mc/share/doc/mc"
cp -a "$OUT/root/." "$STAGE/"
rm -f "$STAGE/opt/mc/bin/mc" "$STAGE/opt/mc/bin/mcedit" "$STAGE/opt/mc/bin/mcview" "$STAGE/opt/mc/bin/mcdiff"
install -m 755 "$OUT/mc" "$STAGE/opt/mc/bin/mc.bin"      # the stripped, statically linked binary
# Wrapper (mc, mcedit, mcview, mcdiff are links to it). osso-xterm changes its size after the start and the first screen of mc came out
# garbled (panels shifted, stray characters) until a key was pressed: the wrapper sends mc a SIGWINCH shortly after the start, so it reads
# the final size and redraws. exec keeps the process id, so the delayed signal reaches mc; kill -0 checks it is still alive.
cat > "$STAGE/opt/mc/bin/mc" <<'WRAP'
#!/bin/sh
# Wrapper for Midnight Commander on the N900: redraw after the terminal has settled, then run the real binary (mc.bin).
me=$$
( for d in 1 2; do sleep $d; kill -0 $me 2>/dev/null && kill -WINCH $me 2>/dev/null; done ) </dev/null >/dev/null 2>&1 &
case "${0##*/}" in
    mcedit) exec /opt/mc/bin/mc.bin -e "$@" ;;
    mcview) exec /opt/mc/bin/mc.bin -v "$@" ;;
    mcdiff) exec /opt/mc/bin/mc.bin -d "$@" ;;
    *)      exec /opt/mc/bin/mc.bin "$@" ;;
esac
WRAP
chmod 755 "$STAGE/opt/mc/bin/mc"
for b in mcedit mcview mcdiff; do ln -s mc "$STAGE/opt/mc/bin/$b"; done
for b in mc mcedit mcview mcdiff; do ln -s "../../opt/mc/bin/$b" "$STAGE/usr/bin/$b"; done
install -m 644 "$OUT/COPYING" "$STAGE/opt/mc/share/doc/mc/COPYING"

SECTION=user/utilities
DEPENDS="libc6 (>= 2.5)"
DISPLAY_NAME="Midnight Commander"
SHORT_DESC="mc $VERSION two-panel file manager"
LONG_DESC="Midnight Commander $VERSION: file manager with two panels in the terminal (mc), the editor mcedit and the viewer mcview. Copy, move, search,
archives (tar, zip, ...) as directories, FTP and SMB are not built in. F-keys work in xterm; where they do not, use Esc followed by a digit (Esc 1 = F1).
Built for Maemo 5 with static GLib 2.66 and ncursesw (UTF-8), without X11, GPM, SFTP and NLS. Upstream: https://midnight-commander.org"
MAINTAINER="elPytel (build of upstream mc by the Midnight Commander team)"
debpack_build
