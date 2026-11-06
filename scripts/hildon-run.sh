#!/bin/bash
# Run INSIDE the Workshop: start an ARM program (python3 script or any binary) with the real GTK 2.14 / Hildon libraries
# of the Fremantle sysroot under qemu-user, on a virtual X screen of the container (Xvfb, 800x480 like the N900).
#   scripts/hildon-run.sh script.py                 ... run a Python 3 script (the cross-built ARM python3)
#   SHOT=out.png SHOT_AFTER=6 scripts/hildon-run.sh script.py   ... screenshot after 6 s
#   PY2=1 scripts/hildon-run.sh script.py          ... run it with the phone's Python 2.5 + PyGTK + Hildon (like mutt-hildon)
#   VNC=1 scripts/hildon-run.sh script.py           ... also serve the screen over VNC (port 5999 of the container)
# Needs: make python3 (the ARM interpreter), make hildon-overlay (theme/fonts from the phone), apt: xvfb x11vnc imagemagick.
set -euo pipefail
PROJ=/project
PY="${PY:-$PROJ/build/out/python3-3.11.18/root/opt/python3}"
D="${XDISPLAY:-:99}"
pgrep -x Xvfb >/dev/null || { Xvfb "$D" -screen 0 800x480x24 >/tmp/xvfb.log 2>&1 & sleep 1.5; }
[ -z "${VNC:-}" ] || pgrep -x x11vnc >/dev/null || x11vnc -display "$D" -rfbport 5999 -forever -nopw -shared -bg -q >/dev/null 2>&1
# LC_ALL=C: the glibc 2.5 of the sysroot cannot read the locale files of the host.
# GTK2_RC_FILES: the theme the phone chooses through xsettings (hildon-desktop is not running here).
export DISPLAY="$D" PYTHONHOME="$PY" QEMU_LD_PREFIX="$PROJ/sysroot" LC_ALL=C LANG=C \
       GTK2_RC_FILES=/usr/share/themes/beta/gtk-2.0/gtkrc
if [ -n "${SHOT:-}" ]; then
    ( sleep "${SHOT_AFTER:-6}"; import -display "$D" -window root "$SHOT" ) &
fi
if [ -n "${PY2:-}" ]; then
    # hildon-stubs: replacement of python-osso (needs the Maemo system bus); EXTRA_PYTHONPATH: the program under test
    export PYTHONPATH="${EXTRA_PYTHONPATH:+$EXTRA_PYTHONPATH:}$PROJ/scripts/hildon-stubs:/usr/lib/pymodules/python2.5/gtk-2.0:/usr/lib/pymodules/python2.5:/usr/lib/python2.5/site-packages"
    unset PYTHONHOME
    exec qemu-arm "$PROJ/sysroot/usr/bin/python2.5" "$@"
fi
exec qemu-arm "$PY/bin/python3.11" "$@"
