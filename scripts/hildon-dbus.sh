#!/bin/bash
# Run INSIDE the Workshop (called by hildon-session.sh and hildon-run.sh): the private D-Bus bus of the emulator and the services
# the Maemo system would provide (scripts/hildon-dbus-mocks.py). One bus serves as "session" and "system" bus of the programs:
#   DBUS_SESSION_BUS_ADDRESS = DBUS_SYSTEM_BUS_ADDRESS = unix:path=/tmp/hildon-emu-bus
# Idempotent. STOP=1 ends the bus and the mocks.
set -euo pipefail
SOCK=/tmp/hildon-emu-bus
if [ -n "${STOP:-}" ]; then
    pkill -f '[h]ildon-dbus-mocks.py' || true
    pkill -f '[h]ildon-emu-bus.conf' || true
    rm -f "$SOCK"
    exit 0
fi
if ! [ -S "$SOCK" ] || ! pgrep -f '[h]ildon-emu-bus.conf' >/dev/null; then
    rm -f "$SOCK"
    cat > /tmp/hildon-emu-bus.conf <<CONF
<!DOCTYPE busconfig PUBLIC "-//freedesktop//DTD D-Bus Bus Configuration 1.0//EN" "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
<busconfig>
  <type>session</type>
  <listen>unix:path=$SOCK</listen>
  <auth>EXTERNAL</auth>
  <policy context="default"><allow send_destination="*" eavesdrop="true"/><allow eavesdrop="true"/><allow own="*"/></policy>
</busconfig>
CONF
    dbus-daemon --config-file=/tmp/hildon-emu-bus.conf --fork
fi
if ! pgrep -f '[h]ildon-dbus-mocks.py' >/dev/null; then
    DBUS_SESSION_BUS_ADDRESS="unix:path=$SOCK" setsid python3 /project/scripts/hildon-dbus-mocks.py >/tmp/hildon-dbus-mocks.out 2>&1 &
    sleep 1
fi
