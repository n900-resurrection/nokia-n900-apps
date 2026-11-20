#!/bin/bash
# Package the built cmus as a .deb for Maemo 5. Run INSIDE the Workshop after build.sh: make -C apps/cmus deb
# Output: /project/build/deb/cmus_<VERSION>-<REV>_armel.deb   (the menu entry opens it in the terminal)
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=cmus
VERSION="${VERSION:-2.13.0}"
OUT="$PROJ/build/out/$PKG-$VERSION"
SRC="$PROJ/build/src/cmus-$VERSION"
STAGE="$PROJ/build/deb/stage-$PKG"
[ -x "$OUT/root/opt/cmus/bin/cmus" ] || { echo "Missing build output in $OUT, run build.sh first (make build)"; exit 1; }

rm -rf "$STAGE"; mkdir -p "$STAGE/opt" "$STAGE/usr/bin"
cp -a "$OUT/root/opt/cmus" "$STAGE/opt/"
mkdir -p "$STAGE/opt/cmus/share/doc/cmus"
install -m 644 "$SRC/COPYING" "$SRC/AUTHORS" "$STAGE/opt/cmus/share/doc/cmus/"
install -m 644 "$PROJ/apps/ffmpeg/../cmus/README.Maemo" "$STAGE/opt/cmus/share/doc/cmus/README.Maemo"
# /usr/bin/cmus: a short wrapper (the terminal of the phone sets TERM=xterm; the data of the phone's music is in ~/MyDocs/.sounds)
cat > "$STAGE/usr/bin/cmus" <<'EOW'
#!/bin/sh
# cmus of the package cmus (see /opt/cmus/share/doc/cmus/README.Maemo)
exec /opt/cmus/bin/cmus "$@"
EOW
chmod 755 "$STAGE/usr/bin/cmus"
ln -s "../../opt/cmus/bin/cmus-remote" "$STAGE/usr/bin/cmus-remote"
debpack_desktop "Music (cmus)" "/usr/bin/cmus" "$PROJ/apps/cmus/icon.png"

SECTION=user/multimedia
DEPENDS="libc6, libpulse0"
DISPLAY_NAME="cmus (music player)"
SHORT_DESC="cmus $VERSION music player for the terminal"
LONG_DESC="cmus $VERSION: a small and fast music player for the terminal with a library, playlists, a play queue, search and filters, and a
remote control (cmus-remote). Keys: 1-7 change the views, :add ~/MyDocs/.sounds adds a folder, Enter plays, c pauses, b/v next/stop, z/x
previous/play, / searches, :q quits. It plays mp3, aac/m4a, opus, ogg vorbis, flac, alac, ape and wav through one input plugin made with the
ffmpeg of this project, and sounds through PulseAudio, so the volume of the phone is the volume of the player. The menu entry opens it in the
terminal. Upstream: https://cmus.github.io"
MAINTAINER="elPytel (build of upstream cmus by Timo Hirvonen, Kevin Ko and contributors)"
debpack_man "$OUT/root/opt/cmus/share/man/man1/cmus.1" "$OUT/root/opt/cmus/share/man/man1/cmus-remote.1" "$OUT/root/opt/cmus/share/man/man7/cmus-tutorial.7"
debpack_build
