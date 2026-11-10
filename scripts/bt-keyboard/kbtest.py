#!/opt/python3/bin/python3
"""Keyboard test window for the N900 (Python 3 + hildonlite): an editable text field and a one-line entry, to see which keys an application receives
(letters, Shift, Caps Lock, Enter, Tab, Delete, Home/End, PgUp/PgDn, AltGr, Czech letters). Run as user: DISPLAY=:0 python3 kbtest.py"""
import hildonlite as hl

hl.init()
win = hl.Window("Keyboard test")
root = hl.VBox(spacing=6)
root.add(hl.Label("Type here: Shift, Caps Lock, Enter, Tab, Delete, Home/End, PgUp/PgDn, AltGr"))
last = hl.Label("last key: -")
root.add(last)
NAMES = {0xff0d: "Return", 0xff09: "Tab", 0xffe5: "Caps_Lock", 0xffff: "Delete", 0xff08: "BackSpace", 0xff50: "Home", 0xff57: "End", 0xff55: "Prior", 0xff56: "Next",
         0xffe1: "Shift_L", 0xffe2: "Shift_R", 0xffe3: "Control_L", 0xff8d: "KP_Enter", 0xfe03: "ISO_Level3_Shift"}
def seen(keyval, state, hw):
    last.set_text("last key: %s (0x%x) state 0x%x keycode %d" % (NAMES.get(keyval, chr(keyval) if 32 < keyval < 127 else "?"), keyval, state, hw))
    return False                                    # do not consume: the field still gets the key
entry = hl.Entry("")
root.add(entry)
text = hl.TextView("one\\ntwo\\nthree\\nfour\\nfive\\n" * 6, editable=True)
area = hl.PannableArea()
area.add(text)
root.add(area, expand=True)
root.add(hl.Button("Quit", on_clicked=lambda b: hl.quit()))
win.add(root)
win.on_key(seen)
win.show()
hl.main()
