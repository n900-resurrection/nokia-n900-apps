#!/opt/python3/bin/python3
"""Split a combined keyboard+pointer input device into two devices and give the keyboard a layout (run ON THE PHONE as root):
    btkbd-split.py [--layout cz|us|none] [NAME-PART]        (NAME-PART default "Keyboard")

Why: the X server of Maemo 5 (1.6.99) does not pass the modifier state (Shift, Ctrl, Caps Lock) of a device that is both keyboard and pointer (ThinkPad
Bluetooth keyboards with a TrackPoint) to the core keyboard, so applications never see Shift. A pure keyboard device works like the built-in keypad.
The script takes the device exclusively (EVIOCGRAB) and passes its events on to two uinput devices: "<name> (keys)" gets the keys, "<name> (pointer)"
the pointer buttons and relative axes. The keys are translated on the way (btkbd_layout.py: Czech QWERTZ, AltGr characters, Caps Lock, right Shift/Ctrl).
It runs until the device disappears (the keyboard disconnects); bt-keyboard.sh starts it again after reconnecting.
"""
import fcntl, os, select, struct, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import btkbd_layout as L

EV_SYN, EV_KEY, EV_REL, EV_MSC, EV_REP = 0, 1, 2, 4, 0x14
UI_SET_EVBIT, UI_SET_KEYBIT, UI_SET_RELBIT, UI_DEV_CREATE, UI_DEV_DESTROY = 0x40045564, 0x40045565, 0x40045566, 0x5501, 0x5502
EVIOCGRAB = 0x40044590


def find_device(part):
    """(name, /dev/input/eventN) of the first input device whose name contains `part` and that has both keys and relative axes... or just keys."""
    name = handlers = None
    for line in open("/proc/bus/input/devices"):
        if line.startswith("N: Name="):
            name = line.split("=", 1)[1].strip().strip('"')
        elif line.startswith("H: Handlers=") and name and part.lower() in name.lower() and "(keys)" not in name and "(pointer)" not in name:
            for h in line.split():
                if h.startswith("event"):
                    return name, "/dev/input/" + h
    return None, None


def evbits(fd, ev, nbytes=96):
    buf = bytearray(nbytes)
    fcntl.ioctl(fd, (2 << 30) | (nbytes << 16) | (0x45 << 8) | (0x20 + ev), buf)
    return [i * 8 + b for i in range(nbytes) for b in range(8) if buf[i] >> b & 1]


def make_uinput(name, evs, keys, rels):
    fd = os.open("/dev/input/uinput", os.O_WRONLY)
    for ev in evs:
        fcntl.ioctl(fd, UI_SET_EVBIT, ev)
    for k in keys:
        fcntl.ioctl(fd, UI_SET_KEYBIT, k)
    for r in rels:
        fcntl.ioctl(fd, UI_SET_RELBIT, r)
    # struct uinput_user_dev: name[80], input_id (bustype, vendor, product, version), ff_effects_max, absmax/absmin/absfuzz/absflat[64]
    os.write(fd, struct.pack("80sHHHHi" + "i" * 256, name.encode()[:79], 5, 1, 1, 1, 0, *([0] * 256)))
    fcntl.ioctl(fd, UI_DEV_CREATE)
    return fd


def is_key_code(c):          # keyboard keys; BTN_MOUSE.. (0x110-0x11f) and the other BTN_ codes (0x100-0x15f) belong to the pointer
    return c < 0x100 or c >= 0x160


class Layout:
    """Key translation: feed() takes one input key event and returns the list of (code, value) events for the new keyboard device."""

    def __init__(self, name):
        self.lay = L.LAYOUTS.get(name) if name != "none" else None
        self.spare = L.spare_codes(name) if self.lay else {}
        self.shift = self.altgr = self.ctrl = 0                # physical modifiers held (counts)
        self.caps = False
        self.held = {}                                          # input code -> output codes, so that the release matches the press

    def out_codes(self):
        return {c for outs in self.held.values() for c in outs}

    def feed(self, code, value):
        if value == 2:                                          # kernel auto-repeat: the X server repeats keys itself
            return []
        if self.lay is None:
            return [(code, value)]
        if code == L.KEY_CAPSLOCK:                              # Caps Lock is handled here (the letters of the phone map ignore the X lock)
            if value == 1:
                self.caps = not self.caps
            return []
        if value == 0:
            return [(c, 0) for c in reversed(self.held.pop(code, [code]))]
        # press
        if code == L.KEY_RIGHTSHIFT: code_out = L.KEY_LEFTSHIFT
        elif code == L.KEY_RIGHTCTRL: code_out = L.KEY_LEFTCTRL
        else: code_out = code
        if code_out == L.KEY_LEFTSHIFT: self.shift += 1
        if code_out == L.KEY_LEFTCTRL: self.ctrl += 1
        if code == L.KEY_RIGHTALT: self.altgr += 1
        lay = self.lay
        key = code
        if lay["swap_yz"] and key in (21, 44):
            key = 65 - key                                      # Y (21) <-> Z (44)
        ctrl = self.ctrl > 0
        if not ctrl and self.altgr and (code, "ag") in self.spare:
            outs = [self.spare[(code, "ag")]]
        elif not ctrl and (code, "pl") in self.spare:
            outs = [self.spare[(code, "pl")]]
        elif key in L.LETTERS and not ctrl and self.caps:
            # Caps Lock flips the case: wrap the letter in a Shift press (or a Shift release when Shift is held)
            if self.shift > 0:
                self.held[code] = [key]
                return [(L.KEY_LEFTSHIFT, 0), (key, 1), (L.KEY_LEFTSHIFT, 1)]
            self.held[code] = [key]
            return [(L.KEY_LEFTSHIFT, 1), (key, 1), (L.KEY_LEFTSHIFT, 0)]
        else:
            outs = [code_out if code_out != code else key]
        self.held[code] = outs
        return [(c, 1) for c in outs]

    def modifier_release(self, code):
        if code in (L.KEY_LEFTSHIFT, L.KEY_RIGHTSHIFT): self.shift = max(0, self.shift - 1)
        if code in (L.KEY_LEFTCTRL, L.KEY_RIGHTCTRL): self.ctrl = max(0, self.ctrl - 1)
        if code == L.KEY_RIGHTALT: self.altgr = max(0, self.altgr - 1)


def emit(fd, typ, code, value):
    os.write(fd, struct.pack("<IIHHi", 0, 0, typ, code, value))


def main():
    args = sys.argv[1:]
    layout = "cz"
    if "--layout" in args:
        i = args.index("--layout"); layout = args[i + 1]; del args[i:i + 2]
    part = args[0] if args else "Keyboard"
    name, path = find_device(part)
    if not path:
        sys.exit("no input device with %r in its name" % part)
    src = os.open(path, os.O_RDWR)
    keys_all = evbits(src, EV_KEY)
    try:
        rels = evbits(src, EV_REL, 2)
    except OSError:
        rels = []
    keys = [k for k in keys_all if is_key_code(k)]
    lay = Layout(layout)
    for extra in list(lay.spare.values()) + [L.KEY_LEFTSHIFT, L.KEY_LEFTCTRL]:
        if extra not in keys:
            keys.append(extra)
    btns = [k for k in keys_all if not is_key_code(k)]
    print("%s: %s, %d keys, %d buttons, %d relative axes" % (name, path, len(keys), len(btns), len(rels)), flush=True)
    kfd = make_uinput(name + " (keys)", [EV_KEY, EV_SYN, EV_MSC], keys, [])
    pfd = make_uinput(name + " (pointer)", [EV_KEY, EV_REL, EV_SYN], btns, rels) if (btns or rels) else None
    fcntl.ioctl(src, EVIOCGRAB, 1)
    print("running: the original device is grabbed, the two new devices are created", flush=True)
    try:
        while True:
            select.select([src], [], [])
            try:
                data = os.read(src, 16 * 64)
            except OSError:
                break                                              # the device is gone
            if not data:
                break
            for i in range(0, len(data) - 15, 16):
                ev = data[i:i + 16]
                typ, code, value = struct.unpack_from("<HHi", ev, 8)
                if typ == EV_KEY and is_key_code(code):
                    if value == 0:
                        lay.modifier_release(code)
                    for c, v in lay.feed(code, value):
                        emit(kfd, EV_KEY, c, v)
                        emit(kfd, EV_SYN, 0, 0)               # one event and a SYN per write: the uinput of kernel 2.6.28 takes exactly one event per write()
                elif typ == EV_KEY or typ == EV_REL:
                    if pfd is not None:
                        os.write(pfd, ev)
                elif typ == EV_SYN and pfd is not None:
                    os.write(pfd, ev)
    finally:
        for fd in (kfd, pfd):
            if fd is not None:
                try: fcntl.ioctl(fd, UI_DEV_DESTROY)
                except OSError: pass
        print("device gone, stopped", flush=True)


if __name__ == "__main__":
    main()
