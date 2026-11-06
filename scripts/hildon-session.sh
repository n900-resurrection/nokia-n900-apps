#!/bin/bash
# Run INSIDE the Workshop: the emulated Fremantle desktop = virtual screen (Xvfb 800x480) + window manager (matchbox)
# + top bar and launcher (scripts/hildon-shell.py). Used by `make emulator` and by `make hildon-run APP=...`.
#   FOREGROUND=1 ... run the bar in the foreground (the session ends with it); otherwise it runs in the background
#   FRESH=1      ... end a previous session first;  STOP=1 ... only end it
#   NOSHELL=1    ... only the screen and the window manager
#   VNC=1        ... also serve the screen over VNC (port 5999)
# The applications run under qemu-user (scripts/hildon-run.sh) and appear below the bar (800x424), like on the N900.
set -euo pipefail
PROJ=/project
D="${XDISPLAY:-:99}"
export DISPLAY="$D" PROJ NO_AT_BRIDGE=1
# FRESH=1 (make emulator, make hildon-run APP=...): end a previous session first (old screen, VNC, window manager, bar, programs);
# STOP=1 only does that (make emulator-stop). Processes of an earlier session survive the end of the command that started them.
if [ -n "${FRESH:-}${STOP:-}" ]; then
    for n in qemu-arm xterm matchbox-window x11vnc Xvfb; do pkill -x "$n" || true; done
    pkill -f '[h]ildon-shell.py' || true
    sleep 1
    mountpoint -q /opt && sudo umount /opt || true
    [ -z "${STOP:-}" ] || exit 0
fi
# Packages run like on the phone: the kernel starts ARM programs through qemu-user (binfmt_misc) and the sysroot /opt is bind-mounted on
# /opt (qemu-user does not translate the path of execve, so wrapper scripts that `exec /opt/<app>/bin/<prog>` need the real path).
# Needs sudo (the Workshop has it); the binfmt entry lives until the Workshop restarts.
BINFMT=/proc/sys/fs/binfmt_misc
[ -e $BINFMT/register ] || sudo mount -t binfmt_misc binfmt_misc $BINFMT 2>/dev/null || true
if [ -e $BINFMT/register ] && [ ! -e $BINFMT/qemu-arm ]; then
    printf ':qemu-arm:M::\\x7fELF\\x01\\x01\\x01\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x02\\x00\\x28\\x00:\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\x00\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xfe\\xff\\xff\\xff:/usr/bin/qemu-arm:F\n' \
        | sudo tee $BINFMT/register >/dev/null || true
fi
mountpoint -q /opt || sudo mount --bind "$PROJ/sysroot/opt" /opt || true
pgrep -x Xvfb >/dev/null || { Xvfb "$D" -screen 0 800x480x24 >/tmp/xvfb.log 2>&1 & sleep 1.5; }
if [ -n "${VNC:-}" ]; then
    pgrep -x x11vnc >/dev/null || x11vnc -display "$D" -rfbport 5999 -forever -nopw -shared -bg -q >/dev/null 2>&1
    echo "Emulator screen over VNC: $(hostname -I | awk '{print $1}'):5999 (remmina, vncviewer)" >&2
fi
pgrep -x matchbox-window >/dev/null || pgrep -f matchbox-window-manager >/dev/null || {
    setsid matchbox-window-manager -display "$D" -use_titlebar no -use_desktop_mode plain >/tmp/matchbox.log 2>&1 &
    sleep 1; }
[ -z "${NOSHELL:-}" ] || exit 0     # only the screen and the window manager
if [ -n "${FOREGROUND:-}" ]; then
    exec python3 "$PROJ/scripts/hildon-shell.py"
fi
pgrep -f hildon-shell.py >/dev/null || { setsid python3 "$PROJ/scripts/hildon-shell.py" >/tmp/hildon-shell.log 2>&1 & sleep 1.5; }
