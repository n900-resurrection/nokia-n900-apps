#!/bin/bash
# Build gPodder 2.20.3 for Maemo 5 from the upstream git tag obsolete/maemo5 (Python 2.5, PyGTK, Hildon). Run INSIDE the Workshop:
#   make -C apps/gpodder build
# gPodder is pure Python: nothing is compiled. setup.py needs Python 2, which the workshop does not have, so this script does
# what "setup.py install --root" (TARGET=maemo) does: the four Python packages, the scripts, the data files from data_files
# of setup.py, the translations (msgfmt of data/po/*.po) and the D-Bus service file.
# Output: /project/build/out/gpodder-$VERSION/root  (file tree of the package, prefix /usr)
set -euo pipefail

VERSION="${VERSION:-2.20.3}"
COMMIT=0bfdbc84a2927e532ca2a2877157e54670515a5e   # tag obsolete/maemo5 "gPodder 2.20.3-1 for Fremantle"
PROJ=/project
DL="$PROJ/build/downloads"
SRCDIR="$PROJ/build/src"
OUT="$PROJ/build/out/gpodder-$VERSION"
SRC="$SRCDIR/gpodder-$VERSION"
R="$OUT/root"
P=/usr

mkdir -p "$DL" "$SRCDIR"
f="gpodder-$COMMIT.tar.gz"
[ -s "$DL/$f" ] || curl -fL --retry 3 -o "$DL/$f" "https://github.com/gpodder/gpodder/archive/$COMMIT.tar.gz"
echo "sha256 $(sha256sum "$DL/$f" | cut -d' ' -f1)  $f"
rm -rf "$SRC" "$OUT"; mkdir -p "$SRC" "$R"
tar -C "$SRC" --strip-components=1 -xzf "$DL/$f"
cd "$SRC"
grep -q "^__version__ *= *'$VERSION'" src/gpodder/__init__.py || { echo "Source version is not $VERSION"; exit 1; }

# ytdlp.patch: HTTPS through curl 8 (Python 2.5 has TLS 1.0 only: feeds, downloads) and YouTube through yt-dlp (new module gpodder/ytdlp.py,
# changes in youtube.py, download.py, feedcore.py; the old YouTube interface does not exist any more)
patch -p1 < "$PROJ/apps/gpodder/ytdlp.patch" > "$OUT/patch.log"

inst() { install -D -m "$1" "$2" "$R$P/$3"; }          # inst <mode> <file> <target relative to prefix>
# 1. Python packages (setup.py: packages, target maemo; only the *.py of each package directory)
SP="lib/python2.5/site-packages"
for pkg in gpodder gpodder/gtkui gpodder/gtkui/interface gpodder/gtkui/maemo gpodder/gtkui/frmntl; do
    for py in src/$pkg/*.py; do inst 644 "$py" "$SP/${py#src/}"; done
done
# 2. scripts: shebang of the Python 2.5 of the phone (distutils would do the same)
for s in bin/* data/maemo/gpodder-mplayer; do
    inst 755 "$s" "bin/$(basename "$s")"
    sed -i '1s|^#!.*python.*$|#!/usr/bin/python2.5|' "$R$P/bin/$(basename "$s")"
done
# 3. data files (setup.py data_files, MAEMO part)
for f in doc/man/*.1; do inst 644 "$f" "share/man/man1/$(basename "$f")"; done
for f in data/ui/*.ui; do inst 644 "$f" "share/gpodder/ui/$(basename "$f")"; done
for f in data/ui/maemo/*.ui; do inst 644 "$f" "share/gpodder/ui/maemo/$(basename "$f")"; done
for f in data/ui/frmntl/*.ui; do inst 644 "$f" "share/gpodder/ui/frmntl/$(basename "$f")"; done
inst 644 data/credits.txt share/gpodder/credits.txt
for f in data/images/*.png; do inst 644 "$f" "share/gpodder/$(basename "$f")"; done
inst 644 data/gpodder.png share/pixmaps/gpodder.png
inst 644 data/maemo/gpodder.desktop share/applications/hildon/gpodder.desktop
inst 644 data/icons/64/gpodder.png share/icons/hicolor/scalable/apps/gpodder.png
for sz in 40 32 26 16; do inst 644 "data/icons/$sz/gpodder.png" "share/icons/hicolor/${sz}x${sz}/apps/gpodder.png"; done
sed "s|__PREFIX__|$P|" data/org.gpodder.service.in > "$OUT/org.gpodder.service"
inst 644 "$OUT/org.gpodder.service" share/dbus-1/services/org.gpodder.service
# 4. translations
n=0
for po in data/po/*.po; do
    lang=$(basename "$po" .po)
    mkdir -p "$R$P/share/locale/$lang/LC_MESSAGES"
    msgfmt -o "$R$P/share/locale/$lang/LC_MESSAGES/gpodder.mo" "$po" && n=$((n+1))
done
# 5. egg-info like distutils
mkdir -p "$R$P/$SP"
printf 'Metadata-Version: 1.0\nName: gpodder\nVersion: %s\nSummary: media aggregator\nHome-page: http://gpodder.org/\nAuthor: Thomas Perl\nLicense: UNKNOWN\nPlatform: UNKNOWN\n' "$VERSION" > "$R$P/$SP/gpodder-$VERSION.egg-info"
cp debian/postinst "$OUT/postinst"
cp debian/changelog "$OUT/changelog"
cp COPYING "$OUT/COPYING"
echo "== Check: $(find "$R" -type f | wc -l) files, $n translations"
# Syntax check with the real Python 2.5 (from the phone, under qemu; needs make hildon-overlay), skipped when it is missing.
if [ -x "$PROJ/sysroot/usr/bin/python2.5" ]; then
    export LC_ALL=C QEMU_LD_PREFIX="$PROJ/sysroot"
    qemu-arm "$PROJ/sysroot/usr/bin/python2.5" -c "
import sys, glob, os
bad = 0
for dp, dn, fn in os.walk('$R$P/$SP/gpodder'):
    for f in fn:
        if f.endswith('.py'):
            try: compile(open(os.path.join(dp, f)).read() + '\\n', f, 'exec')
            except SyntaxError, e: print f, e; bad += 1
print 'Python 2.5 syntax check: %d problems' % bad
sys.exit(bad and 1 or 0)"
fi
