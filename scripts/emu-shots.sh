#!/bin/bash
# Take a series of screenshots of an application in the emulated desktop, driven by a timeline. Run INSIDE the Workshop:
#   make emu-shots [APP=mutt-hildon]            or      scripts/emu-shots.sh [--compare DIR] app...
# The scenario of an application is apps/<app>/shots.txt, one line per step: SECONDS ACTION [ARGS] (the time counts from the start of the program):
#     8   shot list            screenshot (800x480, the whole desktop with the top bar) to build/shots/<app>/list.png
#     9   click 400 100        a tap at x y (xdotool)
#     12  key Escape           a key (xdotool key): F4 = Menu, Escape = Back (like the keys of the N900)
#     14  type hello           text typed into the focused widget
#   Empty lines and lines starting with # are ignored. Use the demo data of the application (apps/<app>/hildon-run.sh), never real data.
# The program starts fresh for every run, so the images are reproducible; build/shots/<app>/contact-sheet.png shows all of them at once
# (ImageMagick montage). With --compare DIR every image is compared with DIR/<app>/<name>.png (pixels that differ), to notice a changed look.
# What it cannot do: hardware (keyboard, sensors, the real top bar of hildon-desktop), anything that needs a service that is not mocked.
set -uo pipefail
PROJ="${PROJ:-/project}"
D="${XDISPLAY:-:99}"
COMPARE=""
[ "${1:-}" = "--compare" ] && { COMPARE="$2"; shift 2; }
[ $# -gt 0 ] || { echo "usage: scripts/emu-shots.sh [--compare DIR] app..." >&2; exit 2; }

stop_session() { env STOP=1 XDISPLAY="$D" "$PROJ/scripts/hildon-session.sh" >/dev/null 2>&1 || true; }
fail=0
for app in "$@"; do
    f="$PROJ/apps/$app/shots.txt"
    [ -f "$f" ] || { echo "== $app: no apps/$app/shots.txt"; continue; }
    out="$PROJ/build/shots/$app"; mkdir -p "$out"
    find "$out" -maxdepth 1 -name '*.png' -delete
    last=$(awk '!/^[[:space:]]*(#|$)/ {t=$1} END {print t+0}' "$f")
    printf '\n== %s (%s s)\n' "$app" "$last"
    stop_session
    log="$PROJ/build/shots/$app.log"
    # the program and the desktop run in the background; the timeline below drives them from outside
    ( APP="$app" timeout $((last + 25)) "$PROJ/scripts/hildon-run.sh" > "$log" 2>&1 ) &
    t0=$(date +%s.%N)
    n=0
    while read -r secs action args; do
        case "$secs" in ''|'#'*) continue ;; esac
        now=$(date +%s.%N)
        wait_s=$(awk -v a="$t0" -v b="$now" -v s="$secs" 'BEGIN {w = s - (b - a); if (w < 0) w = 0; print w}')
        sleep "$wait_s"
        case "$action" in
            shot)
                name="${args%% *}"
                if DISPLAY="$D" import -window root "$out/$name.png" 2>/dev/null; then n=$((n+1)); printf '  %5s s  shot  %s\n' "$secs" "$name"
                else echo "  $secs s  shot $name FAILED"; fail=$((fail+1)); fi ;;
            click) set -- $args; DISPLAY="$D" xdotool mousemove "$1" "$2" click 1; printf '  %5s s  click %s %s\n' "$secs" "$1" "$2" ;;
            key)   DISPLAY="$D" xdotool key "${args%% *}"; printf '  %5s s  key   %s\n' "$secs" "${args%% *}" ;;
            type)  DISPLAY="$D" xdotool type --delay 80 "$args"; printf '  %5s s  type  %s\n' "$secs" "$args" ;;
            *) echo "  unknown action '$action' in $f" >&2; fail=$((fail+1)) ;;
        esac
    done < "$f"
    stop_session
    sleep 1
    echo "  $n screenshot(s) in build/shots/$app/ (log: build/shots/$app.log)"
    if [ "$n" -gt 1 ] && command -v montage >/dev/null; then
        montage "$out"/*.png -tile 3x -geometry 400x240+6+6 -background '#222' -label '%t' "$out/contact-sheet.png.tmp.png" 2>/dev/null \
            && mv "$out/contact-sheet.png.tmp.png" "$out/contact-sheet.png" && echo "  contact sheet: build/shots/$app/contact-sheet.png"
    fi
    if [ -n "$COMPARE" ]; then
        for p in "$out"/*.png; do
            b=$(basename "$p"); [ "$b" = contact-sheet.png ] && continue
            if [ -f "$COMPARE/$app/$b" ]; then
                d=$(compare -metric AE -fuzz 3% "$p" "$COMPARE/$app/$b" null: 2>&1 | awk '{print $1}')
                printf '  compare %-24s %s differing pixels\n' "$b" "$d"
            else printf '  compare %-24s new (nothing to compare)\n' "$b"; fi
        done
    fi
done
[ "$fail" -eq 0 ]
