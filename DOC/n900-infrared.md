# Infrared transmission on the Nokia N900

Status (2026-11-26): the N900's transmitter driver was loaded and checked, then
unloaded cleanly. The LIRC device reports pulse-transmit capability and is
accessible to the regular `user` account. No IR waveform was sent and no
television was tested.

## What is on this N900

Read-only inspection found:

- Kernel `2.6.28-omap1` and a platform device at
  `/sys/bus/platform/devices/lirc_rx51`.
- The `lirc_rx51.ko` and `lirc_dev.ko` modules are present for this kernel.
  `modinfo` identifies `lirc_rx51` as **"LIRC TX driver for Nokia RX51"**,
  authored by Nokia, and dependent on `lirc_dev`.
- The `pierogi` package (1.1.41) is installed. It includes
  `/opt/pierogi/bin/loadRX51Module` and `unloadRX51Module`; these scripts run
  `modprobe lirc_rx51` and `modprobe --remove lirc_rx51`.
- Pierogi's embedded help says it accesses `/dev/lirc0` directly and does not
  require the LIRC daemon. The `pierogi` application includes profiles for
  families such as Samsung TV, Sony TV and Panasonic TV. The `dreamremote`
  package is a Wi-Fi remote for Linux set-top boxes, not an IR control app.
- There are no `irsend`, `irrecord`, `lircd` or `mode2` command-line tools
  installed.

## Hardware test performed

Before the test, `lirc_rx51` was not loaded, the platform device was unbound,
and `/dev/lirc0` did not exist. Using Pierogi's supplied loader:

1. `loadRX51Module` completed successfully; both `lirc_rx51` and `lirc_dev`
   appeared in `/proc/modules`, and `/dev/lirc0` was created as a
   `root:video` character device.
2. The regular Maemo account `user` is in the `video` group. As `user`, opening
   `/dev/lirc0` and issuing the read-only `LIRC_GET_FEATURES` ioctl succeeded.
   The result was `0x00000302`: pulse transmission (`LIRC_CAN_SEND_PULSE`),
   carrier control (`LIRC_CAN_SET_SEND_CARRIER`) and duty-cycle control
   (`LIRC_CAN_SET_SEND_DUTY_CYCLE`) are reported.
3. `unloadRX51Module` completed successfully. The modules and `/dev/lirc0`
   were gone afterward.

This confirms the kernel transmit interface is available and can be accessed
by the normal user. It does **not** confirm the emitted optical signal, the
effectiveness of a particular remote profile, or control of a TV.

## Can it control a modern TV?

**Potentially, if that TV has an IR receiver and accepts an IR protocol/code
that the sender can produce.** N900's `lirc_rx51` driver exposes a pulse
transmitter; Pierogi has built-in TV profile families for several major
manufacturers. Many TVs still accept IR for power and basic controls, but some
current remotes use Bluetooth or another RF link, and an IR receiver or a
matching code set is not guaranteed on every model.

Pierogi is an old application and its embedded Samsung, Sony and Panasonic
profiles do not prove compatibility with a specific current TV. The TV's exact
model and whether its original remote uses IR need to be checked. There is no
TV model identified for this test, so compatibility remains unverified.

## Safe next test

For a real compatibility test, identify the TV model and check whether it has
an IR receiver. Then use the TV's own make/model or a known matching profile
and try a non-disruptive button first, with the TV in view. Do not send a
power-toggle command unless it is acceptable for the TV to switch state.

The Gothi IR module is **not implemented**. Before designing one, decide
whether it should use Pierogi's existing profiles or support user-supplied
protocol/code data, and how the root-only driver-load operation will be
handled. The actual IR send path should be tested against a known receiver
before adding it to Gothi.
