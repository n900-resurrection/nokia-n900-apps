# FM transmitter on the Nokia N900 (for gothi)

Status: `gothi-fmtx` 0.1.0 was built and installed on the owner's N900 on
2026-11-26; its read-only on-device tests passed (8/8). The transmitter was
not enabled and no RF transmission was made.

## What is present on the phone

Read-only checks over `ssh n900` found:

- N900 kernel `2.6.28-omap1` on ARMv7.
- `/dev/radio0`, with the `fmtx_si4713` kernel driver loaded. The sysfs driver
  is `radio-si4713`.
- `fmtx-middleware` version `0.62+0m5`, which provides `/usr/sbin/fmtxd` and
  `/usr/bin/fmtx_client`.
- D-Bus activation for `com.nokia.FMTx` starts `/usr/sbin/fmtxd` as root.
- The `fmtx_client` usage printed on the phone is:

  ```text
  -f<uint>    Set frequency (in kHz)
  -s<string> Set RDS station name
  -t<string> Set RDS info text
  -p<uint>   Turn fmtx on (1) or off (0)
  ```

- GConf keys are defined in `/usr/share/gconf/schemas/fmtx.schemas`:
  `/system/fmtx/enabled` (boolean, schema default `false`) and
  `/system/fmtx/frequency` (integer, schema default `88100`).
- At the time of the check, the live values were `enabled=false` and
  `frequency=90500` (kHz); `fmtxd` was not running.
- Running `fmtx_client` without options reports `freq_min=88100`,
  `freq_max=107900`, `freq_step=100` (kHz) and `state=disabled`. These are
  device-reported limits, not a statement of what is legally permitted to
  transmit.
- `cfmradio` and `n900-fmrx-enabler` are also installed, but those are for FM
  reception, not transmission.

The existing FM transmitter middleware depends on the system audio stack,
including PulseAudio. The frequency-setting command, the off command and the
disabled-state probe work as the regular Maemo user. Actual transmission,
audio routing and the on command have not been tested.

## Safe command checks

The following checks were run as Maemo user `user` while the transmitter was
disabled:

- `fmtx_client -f90500` returned success. The reported frequency stayed at
  `90500` kHz and the state stayed disabled.
- `fmtx_client -p0` returned success and left the state disabled.
- `fmtx_client 2>&1 | grep -q '^state=disabled$'` matched successfully, so a
  Gothi `switch` can use the `state=` line as its status probe. The corresponding
  `state=enabled` case has not been tested.

No `-p1` command was run. Turning the transmitter on would radiate, so that
test should wait until an FM receiver is available and the local test
conditions are agreed.

## Gothi prototype

The current module runner supports declarative `switch`, `level`, `action`,
`monitor` and `ask` modules. Commands run in the background with timeouts.
Separate module packages install a `module.json` under
`/opt/gothi/modules/<name>/`; see the existing [gothi module documentation](../apps/n900-gothi/README.md)
and examples such as [gothi-timesync](../apps/gothi-timesync/) and
[gothi-gps](../apps/gothi-gps/).

The first package, [`gothi-fmtx`](../apps/gothi-fmtx/), installs two entries:

- **FM transmitter** is a `switch` that reads the `state=` line and uses
  `fmtx_client -p1` / `fmtx_client -p0` to start or stop transmission. It shows
  the configured frequency.
- **FM frequency** is a `level` control using `fmtx_client -f{value}`. It uses
  the frequency range and 100 kHz step reported by this N900.

They are separate entries because the current runner cannot combine switch and
frequency controls on one screen. The user chose manual on/off: transmission
continues after leaving the screen or closing Gothi until explicitly stopped.

The package was deployed with the root Makefile's `make debs APP="gothi-fmtx"
INSTALL=1` target. `make -C apps/gothi-fmtx test` passed 8 on-device checks for
package presence, module discovery and read-only state/frequency commands.

Remaining verification:

1. Verify actual start/stop behavior and audio routing with an FM receiver
   ready; ensure the transmitter is turned off again after the test.
2. Confirm the permitted frequency range and power for the intended test
   location. Do not assume the whole FM broadcast band is legal for local
   transmission.
3. Test actual audio and reception with a real FM radio (for example a
   portable radio or car radio). The Galaxy S21 Ultra is not an FM receiver.

The only frequency-setting command used wrote the already configured
`90500` kHz value while the transmitter was disabled. The transmitter has
never been enabled during these checks.
