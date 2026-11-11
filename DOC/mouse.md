# Mouse pointer on the N900 (Maemo 5)

Notes from 2026-11-11, written while bringing up the Bluetooth keyboard with a TrackPoint ([bluetooth-keyboard.md](bluetooth-keyboard.md)).
Status (2026-11-11): **works** with the patched evdev driver, packaged as the application [bt-kbmouse](../apps/bt-kbmouse) (service + settings GUI). Items marked *[unverified]* come from forum posts and package metadata, not from our own test.

## Result

With `xserver-xorg-input-evdev-mouse` installed (see the last section) the TrackPoint works as a normal mouse: motion, left, right and middle button (X buttons 1, 3, 2), the wheel (X buttons 4 to 7). What the stock stack lacked and bt-kbmouse adds:

- **Linear speed:** `Device Accel Profile` = 3 and `Device Accel Constant Deceleration` = 12 / speed (settings of the GUI; speed 4 gives 3.0), set in the X session by `btkbd-accel.py`.
- **Scrolling:** the keyboard sends the TrackPoint motion and the held middle button, no wheel. The splitter turns the motion into wheel events while the middle button is held (a click without motion stays a click).
- **A visible pointer:** `btkbd-cursor.py show` sets an arrow with a black outline on the root window (Maemo's cursor theme is transparent). Windows that set their own cursor can still hide it; not seen so far.
- Right button: the X server gets it (button 3); most Hildon applications do not use it.

## Short answer

The N900 can draw a pointer, but Maemo hides it on purpose, and the stock input driver does not handle relative devices (mouse, TrackPoint) well.
Both problems were solved by the community in 2010 (package `extmou` and a patched `evdev` driver). Our own measurements agree with that.

## What we measured on the phone (PR 1.3, X server 1.6.99, kernel 2.6.28)

- `Xorg` runs with the `fbdev` driver (omapfb, 800x480). It can draw cursors; nothing hides them at server level.
- The current cursor of the root window (read with XFixes `XFixesGetCursorImage`) is 1x1 with no visible pixel, and the pointer sits in the bottom-right corner (799,479).
- **Every cursor of the theme is invisible:** in `/usr/share/icons/default/cursors` the files `left_ptr`, `arrow`, `xterm`, `fleur`... are symbolic links to `transp`, a transparent image. So `xsetroot -cursor_name left_ptr` alone shows nothing.
- A cursor with our own image (a white arrow with a black outline, made with `XcursorImageCreate` + `XcursorImageLoadCursor`, set with `XDefineCursor` on the root window) **is drawn**. It follows the stylus or finger and hides when the touch ends (the touchscreen driver moves the pointer to the corner on pen-up).
- That also makes the **calibration of the touchscreen visible**: under the finger the arrow shows how far the touch point is off, clearly on the right side of the display. A recalibration would be a separate task.
- The TrackPoint of the keyboard (our uinput device `ThinkPad Keyboard (pointer)`, relative axes) is recognised by the X evdev driver ("Configuring as mouse", 5 buttons, relative axes, wheel), but moving it does not move the visible pointer: the cursor disappears and ends in the corner. The stock evdev (`1:2.1.99-1osso20090206.12`) is a Nokia build that is made for the touchscreen and the keypad.

## Prior art

| What | Where | Notes |
|---|---|---|
| `extmou` 1.0.6 "Mouse Support" | `extras-testing` / `extras-devel`, maintainer Ivaylo Dimitrov (freemangordon) | Depends on `xserver-xorg-input-evdev-mouse`, conflicts with `bt-hid-scripts`. Needs `libconbtui0-hid`, Qt 4, `libxmuu1`. |
| `xserver-xorg-input-evdev-mouse` 2.1.99-1osso20090206.12 (versions `-0mouse` and `-1mouse`) | same repositories | Patched `evdev_drv.so` (28 kB) and a HAL rule `10-x11-evdev.fdi` that binds evdev to `input.keys` and `input.mouse` devices. `Replaces: xserver-xorg-input-evdev`. |
| `xorg-evdev-mouse` 0.2-1fremantle1 | `extras-devel` | Older packaging of the same patched driver. |
| `bluemaemo`, `bt-hid-scripts` | `extras-devel`, forum | Older Bluetooth HID helpers (superseded). |
| Forum guides: [N900 Working Bluetooth Mouse](https://talk.maemo.org/archive/index.php/t-57427.html), [Bluetooth Keyboard + Mouse scripts](https://talk.maemo.org/archive/index.php/t-58258.html), [freemangordon's post](https://talk.maemo.org/showthread.php?p=882713) | talk.maemo.org | The pages were behind an anti-bot wall for our fetch tool, so only search summaries were read *[unverified]*. |

The package index is on our mirror: <https://maemo.plan9.de/apt-mirror/mirror/repository.maemo.org/extras-testing/dists/fremantle/free/binary-armel/Packages.gz> (`.deb` files in `pool/fremantle/free/`). The `.deb` files of `extmou` and the patched evdev were unpacked on the PC only (nothing was installed on the phone).

### How `extmou` makes the pointer visible (read from its files)

1. A HAL rule (`99-x11-external-mouse.fdi`) calls `hal-setup-mouse-cursor.sh` when a device with `input.mouse` is added or removed.
2. The script waits for `hildon-desktop` (stamp file `/tmp/hildon-desktop/desktop-started.stamp`) and 15 s more, shows an info banner ("Connected to ...") and, for the first mouse, **moves the cursor theme directory away**: `/opt/usr/share/icons/default/cursors` -> `cursors.extmou`. Without the theme the X server falls back to its built-in cursor font (visible arrow).
3. `extmousecursor --hide` and `--show` (a small Qt/Xlib program: `XmuCursorNameToIndex`, `XCreateGlyphCursor`, `XDefineCursor`, `XUndefineCursor`) re-applies the cursor in the windows, so the change is seen without a restart.
4. A counter in `/dev/shm/extmou.count` handles several mice; on the last remove the directory is moved back. An upstart job (`extmou-restore-cursors`) restores the theme after an unclean shutdown.

The older guides did the same by hand: replace `transp` by an arrow image, or run `xsetroot -cursor_name arrow` (needs `libxmuu1`), plus the patched `evdev_drv.so`.

### Known problems reported in the forums *[unverified]*

- The pointer disappears in MicroB (the browser sets its own cursor) after clicks or scrolling.
- Some mice stop responding about a second after connecting; pointer stuck in a corner after the screen sleeps (a click moves it again).
- A 2014 report: the cursor stayed invisible even after reinstalling the packages.
- `xsetroot` changes only the root window; windows that set their own cursor override it.

## Measurements with test devices (2026-11-11)

Test rig: a script on the phone creates a uinput device, injects events and reads the X pointer (`XQueryPointer`, button state, and an invisible `InputOnly` window that receives `ButtonPress`). The stock X input stack on the phone: `xserver-xorg-input-evdev 1:2.1.99-1osso20090206.12`, `libxi6 2:1.2.99.1`, HAL binds the driver (`10-x11-input.fdi`).

**Relative devices (mouse, TrackPoint) are unusable with the stock stack:**
- Motion is accelerated far too much: 6 to 16 pixels per count at 100 to 300 counts per second (profile 0). Setting `Device Accel Profile` = 3 (smooth linear) and `Device Accel Constant Deceleration` = 4 (properties, set with `scripts/bt-keyboard/btkbd-accel.py`) makes the gain flat, about 1.3 px per count. Profile -1 is rejected (`BadValue`), 1 too.
- Even then the pointer ends up stuck in a corner: after it reaches an edge, pushes back into the screen often do nothing, and pushing past the left edge once showed the pointer at the opposite side. With the real TrackPoint it "jumped between the corners" and stayed in one.
- **Button codes `BTN_LEFT`, `BTN_RIGHT`, `BTN_MIDDLE` produce no X button events** on a relative device (nothing arrives in a window that selects button events; the wheel `REL_WHEEL` gives buttons 4 and 5 correctly). So clicks with the TrackPoint buttons never worked on this stack.

**A touchscreen-like absolute device works for motion:**
- A uinput device with `ABS_X`, `ABS_Y` (0..4095), `ABS_PRESSURE` and `BTN_TOUCH` declared is classified by HAL as a touchpad, bound to evdev and configured as "touchscreen". The server prints `Calibration factors: 179 3821 3578 255` for it. Mapping measured: pixel x = 0.2195*raw - 39.5, pixel y = 516.5 - 0.1445*raw.
- The pointer follows absolute coordinates **without BTN_TOUCH** (hover), until the first `BTN_TOUCH` release. After a touch/release cycle motion events are ignored until the next touch down. This is how a pen works; there is no hover after a click.
- `BTN_TOUCH` gives X button 1 (press and release verified in a window). `BTN_LEFT` on this device is ignored as well.
- The splitter's `--pointer abs` mode builds on this (position integrated from the TrackPoint counts, left button sent as `BTN_TOUCH`). Result with the real keyboard: **motion perfect, the first click works, afterwards the pointer no longer follows (a click reveals the new position).**

**Open:** a way to get clicks without losing hover. Not found with the stock evdev. Things tried: `BTN_TOOL_PEN` held (it sets button 1 pressed at once), a second relative device only for the buttons (its `BTN_LEFT/RIGHT/MIDDLE` are ignored).

## Plan

1. **Our experiment (done first, no system change):** the splitter (`btkbd-split.py --pointer abs`) turns the relative TrackPoint into a touchscreen-like absolute device. Motion works perfectly; clicks and hover cannot be combined with the stock evdev (see above). The cursor is shown with our own image on the root window (`btkbd-cursor.py show`); applications that set their own (transparent) cursor hide it, to be solved with the cursor theme (a theme with visible cursors found through `Xcursor.theme` in the X resources, or the way `extmou` does it).
2. **Fallback:** install `extmou` and `xserver-xorg-input-evdev-mouse` from `extras-testing` (apt repositories as in [mirror.md](mirror.md)). That replaces the system evdev driver (touchscreen and keypad too), needs an X restart and consent; the original `xserver-xorg-input-evdev` 1:2.1.99-1osso20090206.12+0m5 can be put back with `apt-get install`.
3. Later: touchscreen calibration, a proper packaged solution (own package with the cursor script and a HAL or udev trigger instead of Qt), and mouse use in terminal programs (mc understands mouse events when the terminal sends them).

## Patched evdev installed (2026-11-11)

Only the driver package was installed, not `extmou`: `xserver-xorg-input-evdev-mouse 1:2.1.99-1osso20090206.12-1mouse+0m5` (from `extras-testing`, SHA-256 `007b78dd...5fa7`, depends only on libc). `extmou` needs `libxmuu1`, which is neither on the phone nor in the repositories we have; the cursor is shown by our own script anyway.
`dpkg -i` replaced `/usr/lib/xorg/modules/input/evdev_drv.so` (md5 `aa417ac4...` -> `badeed78...`; the package `xserver-xorg-input-evdev` stays installed, the new one `Replaces` it). The running X server keeps the old driver until it is restarted (reboot).

**Back to the stock driver** (the original file is in `/home/user/backup-evdev/` on the phone, as root):

```sh
dpkg -r xserver-xorg-input-evdev-mouse
cp -p /home/user/backup-evdev/evdev_drv.so /usr/lib/xorg/modules/input/evdev_drv.so
md5sum /usr/lib/xorg/modules/input/evdev_drv.so     # aa417ac495719041f1a407e0b7abeb72
# then reboot
```

(`dpkg -r` removes the file because the new package owns it; the copy puts the stock one back. Alternatively reinstall `xserver-xorg-input-evdev` 1:2.1.99-1osso20090206.12+0m5.)
