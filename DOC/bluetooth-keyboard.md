# Bluetooth keyboard on the N900 (Maemo 5)

Worked out on 2026-11-10 with a Lenovo ThinkPad Bluetooth keyboard with a TrackPoint (Czech layout) on the stock Maemo 5 firmware (kernel 2.6.28-omap1,
bluez 4.60, X server 1.6.99). Result: pairing, typing with Shift / Caps Lock / AltGr / Ctrl, Czech letters, key repeat, arrows, Delete, PgUp/PgDn.
The tools are in [scripts/bt-keyboard/](../scripts/bt-keyboard/); `scripts/bt-keyboard/bt-keyboard.sh` does everything below from the host.

## Quick procedure (after a restart of the phone or a new keyboard)
```bash
scripts/bt-keyboard/bt-keyboard.sh setup                 # once per boot: HID modules, bluez input plugin, tools copied to /home/user/btkbd
scripts/bt-keyboard/bt-keyboard.sh pair D0:13:1E:02:EC:15 0000   # only for a NEW keyboard: LED blinking, then type 0000 + Enter on the keyboard
scripts/bt-keyboard/bt-keyboard.sh start cz ThinkPad     # keyboard connected (press a key): split + Czech layout + key map + key repeat
scripts/bt-keyboard/bt-keyboard.sh test                  # the "Keyboard test" window on the phone (shows keyval, state, keycode of the last key)
scripts/bt-keyboard/bt-keyboard.sh status | stop
```
After a restart: `setup` (the modules are not loaded at boot yet, see "Not persistent"), switch the keyboard on, `start`. A paired keyboard reconnects by itself
when the bluez input plugin is on (the pairing is stored in /var/lib/bluetooth); if it does not, press a key or use Settings > Bluetooth.

## What was wrong and why (each point was measured, not guessed)
1. **Pairing did nothing visible.** `/etc/bluetooth/main.conf` has `DisablePlugins = network,input,hal`: the `input` plugin (HID) is off, so the phone pairs
   but never opens the HID channel. Fix: remove `input` (original saved as `main.conf.orig`), restart with `initctl stop bluetoothd; initctl start bluetoothd`
   (this upstart has no `restart`).
2. **No HID in the kernel.** The modules `hid` and `hidp` exist (`/lib/modules/2.6.28-omap1/`) but are not loaded: `modprobe hid; modprobe hidp`.
3. **The Maemo pairing dialog cannot pair a keyboard.** It asks for a PIN, but the keyboard needs the same PIN typed on it, and the dialog times out
   before. `btpair.py` (Python 2.5 with dbus-python, the system Python of the phone) is our own BlueZ agent: it answers the PIN request with a fixed PIN
   (`0000`), and you type it on the keyboard + Enter within a few seconds. It also forgets a stale pairing record first, marks the keyboard trusted and
   calls `org.bluez.Input.Connect`.
4. **Shift and Ctrl did nothing in applications.** The keyboard is a *combined* device (keyboard + TrackPoint). The X server 1.6.99 does not pass the modifier
   state of such a device to the core keyboard (measured with `XkbGetState`: Shift set on the device, never on the core keyboard), and the master does not even
   see the pressed keys. A pure keyboard device works like the built-in keypad. Fix: `btkbd-split.py` grabs the device (EVIOCGRAB) and re-emits the events
   through two `uinput` devices, "... (keys)" and "... (pointer)". (The uinput of kernel 2.6.28 accepts exactly ONE event per `write()`.)
5. **The key map of the X server is shared by all keyboards.** `xkbcomp -i <external device>` changes the map of the built-in keypad too: it broke Enter
   (KP_Enter became Return) and Ctrl (Fn+Ctrl = Multi_key) of the phone. Never write a keymap "for the external keyboard only". Restore with
   `setxkbmap -device N -keycodes "evdev+aliases(qwerty)" -types "complete+nokia" -compat complete -symbols "nokia_vndr/rx-51(common)+nokia_vndr/rx-51(us)+inet(evdev)" -geometry "nokia(nokiarx51)"`
   for the devices 1 (core) and every slave (`xkbcomp -i N :0 -` shows which map a device has; the phone's xkbcomp writes `LockControls(controls=)` that it cannot
   read back, replace by `NoAction()`).
6. **Therefore the layout is made in user space** (`btkbd_layout.py`): the splitter translates the key codes (Z/Y swap, the Czech number row, `ú ů § ¨`, AltGr
   characters, Caps Lock, right Shift/Ctrl -> left ones). Characters that do not exist in the map of the phone are sent as *spare key codes* (Linux 183 ...,
   X 191 ...), and `btkbd-keymap.py` adds only those to the X key map (additive: the built-in keypad uses none of them). Caps Lock is handled by the splitter,
   because the letter keys of the phone map (FOUR_LEVEL_SEMIALPHABETIC) ignore the X lock.
7. **Key repeat** is off in X for all keys of the phone: `btkbd-keymap.py` switches the RepeatKeys control on for the core keyboard and the keyboard (400 ms, 25/s).
8. The hardware keypad of the phone is hildon-handled for Shift (sticky), so it is no model for an external keyboard; Hildon applications read `event->state`.

## What stays changed on the phone
| change | where | revert |
|---|---|---|
| `input` removed from `DisablePlugins` | `/etc/bluetooth/main.conf` (copy: `main.conf.orig`) | `cp main.conf.orig main.conf`, restart bluetoothd |
| modules hid, hidp loaded | kernel (until reboot) | `rmmod hidp hid` |
| pairing + trust of the keyboard | `/var/lib/bluetooth/80:50:1B:4C:AE:BF/` | Settings > Bluetooth or `Adapter.RemoveDevice` |
| splitter + extra keys + key repeat | running process, X server memory (until X restarts) | `bt-keyboard.sh stop` (the extra keys stay until X restarts, harmless) |
| tools | `/home/user/btkbd/` | delete |

## Not persistent yet (to do)
* Load `hid` and `hidp` at boot (a line in `/etc/modules` or a boot script); then a paired keyboard reconnects without `setup`.
* Start the splitter when the keyboard connects (an upstart job in `/etc/event.d` that polls `/proc/bus/input/devices`, or a udev rule) and run
  `btkbd-keymap.py` as user afterwards (needs the X session). Until then: `bt-keyboard.sh start`.
* Hildon text widgets do not use the Czech keymap of the phone for the on-screen keyboard; that is untouched.

## Another keyboard or layout
* Pair it (`pair ADDRESS [PIN]`; some keyboards show a number on the phone instead of a PIN prompt: look at `/tmp/btpair.log` on the phone: it prints `PASSKEY TO TYPE ...`).
* `start LAYOUT NAME-PART` (`NAME-PART` selects the input device by a part of its name, see `status`). Layouts are tables in `btkbd_layout.py`
  (`LAYOUTS["cz"]`: Linux key code -> symbol and symbol with Shift, and AltGr symbols). Add one per layout; `us` and `none` exist for a keyboard that already matches.
* Find out what an application receives with `bt-keyboard.sh test`: the line "last key" shows keyval, `state` (0x1 Shift, 0x2 Caps Lock, 0x4 Ctrl,
  0x8 Alt, 0x80 AltGr) and the hardware keycode. A key that is delivered to X but does nothing in a program is the program's business (osso-xterm does
  not use PgUp/PgDn; Delete works in GTK text fields).
* A keyboard without a pointer (pure keyboard) does not need the splitting, but then the translation is lost too: the splitter does both.

## Diagnosing (what was used)
* `hciconfig`, `hcitool con`, `dbus-send ... org.bluez.Adapter.ListDevices`, `org.bluez.Input.GetProperties` (Connected), `dmesg | tail` (HIDP line).
* `/proc/bus/input/devices` and `/dev/input/eventN` (raw key codes), `XListInputDevices` (X device ids: the phone has no xinput tool).
* `XkbGetState(display, device, &state)`: the modifier state per X device; this showed bug 4 and the effect of bug 5.
* A first sniffer that grabs the keyboard shows only what the X server delivers (keycode, keysym), not the modifier state of the core keyboard.
