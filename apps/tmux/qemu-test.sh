#!/bin/bash
# Emulation test of tmux under qemu-user (no phone needed). Run INSIDE the Workshop:  make -C apps/tmux qemu-test
# Needs the built package (make tmux) and the locale archive of the phone in the sysroot (make locale-overlay): tmux refuses to start without
# any UTF-8 locale. Runs through scripts/qemu-n900 (kernel 2.6.28, one CPU, 1 MB /tmp). Every call of the wrapper has its own empty /tmp,
# so the socket of the tmux server lives in build/qscratch (a path outside /tmp, shared by the calls).
set -uo pipefail
. "$(dirname "$0")/../../scripts/qemu-lib.sh"
VERSION="${VERSION:-3.8}"
T="$OUT/tmux-$VERSION/root/opt/tmux/bin/tmux"
[ -x "$T" ] || { echo "Missing $T, run: make tmux"; exit 1; }
[ -s "$PROJ/sysroot/usr/lib/locale/locale-archive" ] || { echo "Missing the locale archive in the sysroot, run (on the host): make locale-overlay"; exit 1; }
S=$(scratch); trap 'rm -rf "$S"' EXIT
export LC_ALL=cs_CZ.UTF-8 TERM=xterm
Q="$PROJ/scripts/qemu-n900 $T -S $S/sock"     # a tmux command for sh -c strings
tm() { run "$T" -S "$S/sock" "$@"; }
tm kill-server >/dev/null 2>&1

has version "tmux 3.8" tm -V
check new-session sh -c "$Q new-session -d -s t 'sleep 30' && $Q has-session -t t"
tm kill-server >/dev/null 2>&1
check send-keys-utf8 sh -c "$Q new-session -d -s k sh && $Q send-keys -t k 'echo tmux-works-ěščř' Enter && sleep 2 && $Q capture-pane -p -t k | grep -q 'tmux-works-ěščř'"
check split-window sh -c "$Q split-window -d -t k && test \"\$($Q list-panes -t k | wc -l)\" -eq 2"
check kill-server sh -c "$Q kill-server; ! $Q has-session 2>/dev/null"
# tmux tries en_US.UTF-8 and C.UTF-8 itself, so with the locale archive it starts even when the environment says LC_ALL=C; without any
# UTF-8 locale installed (the empty placeholders of the SDK sysroot) it refuses with "need UTF-8 locale" or "invalid LC_ALL, LC_CTYPE or LANG".
tm kill-server >/dev/null 2>&1
check starts-with-plain-c-locale sh -c "LC_ALL=C $Q new-session -d -s c 'sleep 5' && LC_ALL=C $Q has-session -t c"
tm kill-server >/dev/null 2>&1
qsummary "tmux (qemu)"
