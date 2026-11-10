# Pair a Bluetooth keyboard from the phone with our own agent (Python 2.5, dbus-python): btpair.py ADDRESS [PIN]
# Legacy pairing: the phone answers the PIN request with PIN, you type the same PIN + Enter on the keyboard. SSP: the passkey is shown in the log.
import sys, time, dbus, dbus.service, dbus.mainloop.glib, gobject
addr = sys.argv[1].upper()
pin = sys.argv[2] if len(sys.argv) > 2 else "0000"
log = open("/tmp/btpair.log", "w")
def say(*a):
    log.write(" ".join([str(x) for x in a]) + "\n"); log.flush()
dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
bus = dbus.SystemBus()
mgr = dbus.Interface(bus.get_object("org.bluez", "/"), "org.bluez.Manager")
adapter = dbus.Interface(bus.get_object("org.bluez", mgr.DefaultAdapter()), "org.bluez.Adapter")
loop = gobject.MainLoop()

class Agent(dbus.service.Object):
    @dbus.service.method("org.bluez.Agent", in_signature="", out_signature="")
    def Release(self): say("agent released")
    @dbus.service.method("org.bluez.Agent", in_signature="o", out_signature="s")
    def RequestPinCode(self, dev): say("PIN requested -> answered", pin, "(type it on the keyboard + Enter)"); return pin
    @dbus.service.method("org.bluez.Agent", in_signature="o", out_signature="u")
    def RequestPasskey(self, dev): say("passkey requested -> answered", pin); return dbus.UInt32(int(pin))
    @dbus.service.method("org.bluez.Agent", in_signature="ouq", out_signature="")
    def DisplayPasskey(self, dev, passkey, entered): say("PASSKEY TO TYPE ON THE KEYBOARD:", "%06d" % passkey, "entered", entered)
    @dbus.service.method("org.bluez.Agent", in_signature="ou", out_signature="")
    def RequestConfirmation(self, dev, passkey): say("confirmation", passkey, "-> yes")
    @dbus.service.method("org.bluez.Agent", in_signature="os", out_signature="")
    def Authorize(self, dev, uuid): say("authorize", uuid, "-> yes")
    @dbus.service.method("org.bluez.Agent", in_signature="s", out_signature="")
    def ConfirmModeChange(self, mode): say("mode change", mode)
    @dbus.service.method("org.bluez.Agent", in_signature="", out_signature="")
    def Cancel(self): say("agent cancelled")

agent = Agent(bus, "/btpair/agent")
# forget the old (stale) pairing of this address
try:
    adapter.RemoveDevice(adapter.FindDevice(addr)); say("old record removed"); time.sleep(1)
except Exception, e:
    say("no old record:", e)

def done(path):
    say("PAIRED", path)
    try:
        dev = bus.get_object("org.bluez", path)
        dbus.Interface(dev, "org.freedesktop.DBus.Properties") if False else None
        dbus.Interface(dev, "org.bluez.Device").SetProperty("Trusted", True); say("trusted")
        dbus.Interface(dev, "org.bluez.Input").Connect(); say("input connected")
    except Exception, e:
        say("after pairing:", e)
    loop.quit()
def failed(e):
    say("PAIRING FAILED:", e); loop.quit()
say("pairing", addr, "pin", pin, "- type the PIN on the keyboard when asked")
adapter.CreatePairedDevice(addr, "/btpair/agent", "DisplayOnly", reply_handler=done, error_handler=failed, timeout=90)
gobject.timeout_add(100000, loop.quit)
loop.run()
say("end")
