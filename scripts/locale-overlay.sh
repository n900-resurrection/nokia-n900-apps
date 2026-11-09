#!/bin/bash
# Run on the HOST: copy the locale archive of glibc 2.5 from the phone into ./sysroot (about 23 MB, once; not in git).
# Why: the SDK sysroot has only empty placeholder files for the locales, so under qemu-user every UTF-8 locale is "invalid" and programs that
# insist on one (tmux: "need UTF-8 locale (LC_CTYPE)") cannot run in the emulation. The archive of the phone holds all of them (cs_CZ.utf8 and more)
# in the format of glibc 2.5; the locale files of the host (glibc 2.39) cannot be used.
# Afterwards: qemu-arm -L sysroot ... with LC_ALL=cs_CZ.UTF-8 (Python 2.5 apps of the Hildon emulator still run with LC_ALL=C by default).
set -euo pipefail
cd "$(dirname "$0")/.."
DEVICE="${DEVICE:-n900}"
mkdir -p sysroot/usr/lib/locale
ssh "$DEVICE" 'cat /usr/lib/locale/locale-archive' > sysroot/usr/lib/locale/locale-archive.new
[ -s sysroot/usr/lib/locale/locale-archive.new ] || { echo "empty locale-archive from $DEVICE" >&2; exit 1; }
mv sysroot/usr/lib/locale/locale-archive.new sysroot/usr/lib/locale/locale-archive
echo "locale archive copied into sysroot/ ($(du -h sysroot/usr/lib/locale/locale-archive | cut -f1)); try: LC_ALL=cs_CZ.UTF-8 qemu-arm -L sysroot ..."
