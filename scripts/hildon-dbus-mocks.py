#!/usr/bin/env python3
# D-Bus services of the Maemo 5 system that programs expect and the PC emulator does not have (run INSIDE the Workshop by
# scripts/hildon-dbus.sh on the private bus of the emulator; DBUS_SESSION_BUS_ADDRESS and DBUS_SYSTEM_BUS_ADDRESS point to it).
#   com.nokia.icd                    Internet Connection Daemon: gPodder asks which connection is active (here: none known)
#   com.nokia.mafw.renderer...       media player of the phone (MAFW): gPodder follows what it plays; here an idle player
# More services can be added below: a class per service, named like the original. Calls are logged to /tmp/hildon-dbus-mocks.log.
import sys
import time

import dbus
import dbus.mainloop.glib
import dbus.service
from gi.repository import GLib

LOG = "/tmp/hildon-dbus-mocks.log"


def log(msg):
    with open(LOG, "a") as f:
        f.write("%s %s\n" % (time.strftime("%H:%M:%S"), msg))


class Icd(dbus.service.Object):
    """com.nokia.icd: the connection manager. There is no mobile network or WLAN to ask about."""
    def __init__(self, bus):
        dbus.service.Object.__init__(self, dbus.service.BusName("com.nokia.icd", bus), "/com/nokia/icd")

    @dbus.service.method("com.nokia.icd", in_signature="", out_signature="sussuuu")
    def get_statistics(self):
        log("icd.get_statistics")
        raise dbus.exceptions.DBusException("no connection", name="com.nokia.icd.error.network_error")

    @dbus.service.method("com.nokia.icd", in_signature="u", out_signature="u")
    def state_req(self, flags):
        log("icd.state_req")
        return 0


class MafwRenderer(dbus.service.Object):
    """Media player: nothing is playing."""
    NAME = "com.nokia.mafw.renderer.Mafw-Gst-Renderer-Plugin.gstrenderer"
    PATH = "/com/nokia/mafw/renderer/gstrenderer"
    IFACE = "com.nokia.mafw.renderer"

    def __init__(self, bus):
        dbus.service.Object.__init__(self, dbus.service.BusName(self.NAME, bus), self.PATH)

    @dbus.service.method(IFACE, in_signature="", out_signature="uuus")
    def get_status(self):
        return (0, 0, 0, "")     # playlist, index, state (0 = stopped), object id

    @dbus.service.method(IFACE, in_signature="", out_signature="i")
    def get_position(self):
        return 0

    @dbus.service.method(IFACE, in_signature="ui", out_signature="")
    def set_position(self, mode, position):
        log("mafw.set_position %s %s" % (mode, position))

    @dbus.service.method(IFACE, in_signature="", out_signature="")
    def play(self):
        log("mafw.play")

    @dbus.service.method(IFACE, in_signature="", out_signature="")
    def stop(self):
        log("mafw.stop")

    @dbus.service.method(IFACE, in_signature="", out_signature="")
    def pause(self):
        log("mafw.pause")


def main():
    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    bus = dbus.SessionBus()
    keep = [Icd(bus), MafwRenderer(bus)]
    log("mocks running: %d services" % len(keep))
    GLib.MainLoop().run()


if __name__ == "__main__":
    sys.exit(main())
