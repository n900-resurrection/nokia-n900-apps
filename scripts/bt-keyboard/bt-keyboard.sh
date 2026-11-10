#!/bin/bash
# Bring a Bluetooth keyboard to life on the N900 from the host (everything runs over ssh; see DOC/bluetooth-keyboard.md for the why).
#   scripts/bt-keyboard/bt-keyboard.sh setup            load the HID kernel modules, enable the bluez "input" plugin (main.conf backup: main.conf.orig), restart bluetoothd, copy the tools
#   scripts/bt-keyboard/bt-keyboard.sh pair ADDRESS [PIN]   pair with our own agent (default PIN 0000): type the PIN + Enter on the keyboard when asked
#   scripts/bt-keyboard/bt-keyboard.sh start [LAYOUT] [NAME-PART]   split the keyboard device, make the layout (cz | us | none; default cz) and load the X key map additions
#   scripts/bt-keyboard/bt-keyboard.sh stop             stop the splitter (the keyboard then works as the plain, unsplit device: no Shift in applications)
#   scripts/bt-keyboard/bt-keyboard.sh status | test    state of everything | the key test window on the phone
# The phone is DEVICE (default: the ssh alias n900, root login; the X tools run as user).
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
DEVICE="${DEVICE:-n900}"
SSH=(ssh -o ConnectTimeout=8 "$DEVICE")
quiet() { grep -v -e '^\*\*' -e '^$'; }          # drop the post-quantum warning of the newer OpenSSH
remote() { "${SSH[@]}" "$@" 2>&1 | quiet; }
PY=/opt/python3/bin/python3
DIR=/home/user/btkbd

deploy() {
    remote "mkdir -p $DIR" >/dev/null
    scp -q "$HERE"/btkbd_layout.py "$HERE"/btkbd-split.py "$HERE"/btkbd-keymap.py "$HERE"/kbtest.py "$DEVICE:$DIR/" 2>&1 | quiet
    remote "chmod +x $DIR/*.py; chown -R user $DIR"
}
# the PIDs of the running splitters: ps truncates the command line, so /proc/PID/cmdline is read (the ssh shell itself is not matched: it does not start with the interpreter)
SPLITTER_PIDS='for p in /proc/[0-9]*; do tr "\0" " " < $p/cmdline 2>/dev/null | grep -q "^/opt/python3/bin/python3 .*btkbd-split" && echo ${p#/proc/}; done'
splitter_pids() { remote "$SPLITTER_PIDS"; }

case "${1:-}" in
setup)
    remote 'modprobe hid; modprobe hidp; lsmod | grep -E "^hid"'
    remote '[ -f /etc/bluetooth/main.conf.orig ] || cp /etc/bluetooth/main.conf /etc/bluetooth/main.conf.orig
            sed -i "s/^DisablePlugins = network,input,hal/DisablePlugins = network,hal/" /etc/bluetooth/main.conf; grep ^DisablePlugins /etc/bluetooth/main.conf
            initctl stop bluetoothd >/dev/null 2>&1; sleep 2; initctl start bluetoothd >/dev/null 2>&1; sleep 4; hciconfig | sed -n 1,3p'
    deploy && echo "tools copied to $DIR" ;;
pair)
    addr="${2:?usage: bt-keyboard.sh pair ADDRESS [PIN]}"; pin="${3:-0000}"
    echo "Put the keyboard into pairing mode (the LED blinks) and be ready to type $pin + Enter on it. Starting in 5 s..."
    sleep 5
    scp -q "$HERE/btpair.py" "$DEVICE:/tmp/" 2>&1 | quiet
    ( "${SSH[@]}" "python2.5 /tmp/btpair.py $addr $pin >/tmp/btpair.out 2>&1" ) 2>&1 | quiet &
    for i in $(seq 1 30); do sleep 3; log=$(remote "cat /tmp/btpair.log 2>/dev/null"); case "$log" in *PIN\ requested*) echo ">>> now type $pin + Enter on the keyboard <<<";; esac
        case "$log" in *"end"*) break;; esac; done
    remote "cat /tmp/btpair.log; rm -f /tmp/btpair.py /tmp/btpair.log /tmp/btpair.out" ;;
start)
    layout="${2:-cz}"; part="${3:-ThinkPad}"
    deploy >/dev/null
    for p in $(splitter_pids); do remote "kill $p"; done; sleep 1
    "${SSH[@]}" "nohup $PY $DIR/btkbd-split.py --layout $layout '$part' >/tmp/btkbd-split.log 2>&1 </dev/null &" </dev/null >/dev/null 2>&1 &
    sleep 5
    remote "cat /tmp/btkbd-split.log"
    remote "su user -c 'cd $DIR && DISPLAY=:0 $PY btkbd-keymap.py --layout $layout 2>&1 | tail -3'" ;;
stop)
    for p in $(splitter_pids); do remote "kill $p" && echo "stopped $p"; done ;;
status)
    remote 'hciconfig | sed -n 1,3p; hcitool con; echo "--- input devices:"; grep -E "^N:" /proc/bus/input/devices | tail -4; echo "--- splitter (PIDs):"; '"$SPLITTER_PIDS"'; echo "--- modules:"; lsmod | grep -E "^(hid|hidp)"' ;;
test)
    deploy >/dev/null
    "${SSH[@]}" "su user -c 'cd $DIR && DISPLAY=:0 PYTHONPATH=/opt/python3/lib/python3.11/site-packages nohup $PY kbtest.py >/tmp/kbtest.out 2>&1 </dev/null &'" </dev/null >/dev/null 2>&1 &
    sleep 3; echo "the 'Keyboard test' window is open on the phone" ;;
*) sed -n '2,10p' "$0"; exit 2 ;;
esac
