#!/bin/bash
# Icons of the packages in the catalogue of the web site: icons/packages/<package>.png (64x64), for the packages that have no menu icon of their own.
#  - an application that has an icon (apps/<app>/icons/64.png) gets that one (the five Hildon applications: reused, not redrawn),
#  - a console package gets the look of the console icons (scripts/icon-lib.sh): the dark rounded square, a short name, and the green prompt `>_`
#    under it, the mark of a terminal program (as on the icon of mutt), so a terminal tool and a GUI application differ at first sight,
#  - a package that is not a program (libraries, services, data) gets the short name and an orange bar instead of the prompt (blue for a Python library).
# Run it when a package is added to the table below; the PNGs are committed. scripts/debpack.sh embeds icons/packages/<package>.png in the .deb
# (XB-Maemo-Icon-26) of a package that has no icon otherwise, so the Application Manager shows it too.
set -euo pipefail
cd "$(dirname "$0")/.."
convert() { command convert +set date:create +set date:modify -define png:exclude-chunk=date,time "$@"; }
. scripts/icon-lib.sh
OUT=icons/packages
mkdir -p "$OUT"

# package  text  kind   (term = console program, sys = system/service/data, lib = library for programmers)
TABLE='age age term
apt-n900 apt term
apt-transport-curl apt sys
bash5 bash term
bat bat term
busybox37 bb term
ca-certs-n900 CA sys
camel-lite-ssl3 TLS sys
curl curl term
dialog dlg term
fd fd term
file file term
fzf fzf term
git git term
irssi irc term
jq jq term
libsignal-purple sig sys
mc mc term
microb-nss nss sys
msmtp smtp term
ntp-sync ntp term
openssh ssh term
profanity prof term
purple-echo echo sys
python3-hildonlite hl lib
python3.11 py term
quickjs js term
ripgrep rg term
rsync rsync term
screen scr term
signal-bridge sig sys
smb smb term
strace strc term
terminfo-256color tinfo sys
tig tig term
weechat wee term
wget wget term
whiptail wt term
wireguard-go wg term
xml-tools xml term'

size_for() { case ${#1} in 1|2) echo 124 ;; 3) echo 100 ;; 4) echo 80 ;; *) echo 66 ;; esac; }

while read -r pkg text kind; do
    size=$(size_for "$text")
    if [ "$kind" = term ]; then
        icon_base -font "$FONT" -pointsize "$size" -fill '#f2f2f2' -gravity center -annotate +0-26 "$text" \
                  -pointsize 58 -fill '#4bd16b' -gravity south -annotate +0+26 '>_' /tmp/pkgicon.$$.png
    else
        bar='#f28c28'; [ "$kind" = lib ] && bar='#3d9bd9'
        icon_base -font "$FONT" -pointsize "$size" -fill '#f2f2f2' -gravity center -annotate +0-18 "$text" \
                  -fill "$bar" -draw 'roundrectangle 64,184 192,202 9,9' /tmp/pkgicon.$$.png
    fi
    convert /tmp/pkgicon.$$.png -resize 64x64 "$OUT/$pkg.png"
done <<< "$TABLE"
rm -f /tmp/pkgicon.$$.png

# the Hildon applications: their own icons
for pair in bt-kbmouse:bt-kbmouse ical-sync:ical-sync mutt-hildon:mutt-hildon selfie:selfie sfeed-hildon:sfeed-hildon; do
    pkg=${pair%%:*}; app=${pair##*:}
    convert "apps/$app/icons/64.png" -resize 64x64 "$OUT/$pkg.png"
done

# gpodder: headphones (a white headband, orange ear cups)
icon_base -fill none -stroke '#f2f2f2' -strokewidth 16 -draw 'arc 56,40 200,184 180,360' \
          -fill '#f28c28' -stroke none -draw 'roundrectangle 42,120 90,206 14,14' -draw 'roundrectangle 166,120 214,206 14,14' /tmp/pkgicon.$$.png
convert /tmp/pkgicon.$$.png -resize 64x64 "$OUT/gpodder.png"
rm -f /tmp/pkgicon.$$.png
echo "$(ls $OUT | wc -l) icons in $OUT"
