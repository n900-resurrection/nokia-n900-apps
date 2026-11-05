#!/bin/bash
# Package ntp-sync as a .deb for Maemo 5 (architecture-independent scripts, built as armel).
#   make -C apps/ntp-sync deb
# Output: /project/build/deb/ntp-sync_<VERSION>-<REV>_armel.deb
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=ntp-sync
VERSION="${VERSION:-0.2}"
STAGE="$PROJ/build/deb/stage-$PKG"
HERE="$PROJ/apps/ntp-sync"

rm -rf "$STAGE"
mkdir -p "$STAGE/usr/bin" "$STAGE/etc/network/if-up.d" "$STAGE/etc" "$STAGE/usr/share/man/man1"
install -m 755 "$HERE/ntp-sync" "$STAGE/usr/bin/ntp-sync"
install -m 755 "$HERE/ntp-sync.hook" "$STAGE/etc/network/if-up.d/ntp-sync"
gzip -9n -c "$HERE/ntp-sync.1" > "$STAGE/usr/share/man/man1/ntp-sync.1.gz"
cat > "$STAGE/etc/ntp-sync.conf" <<'EOT'
# NTP servers for ntp-sync, one per line.
pool.ntp.org
time.cloudflare.com
time.google.com
EOT
mkdir -p "$STAGE/DEBIAN"
echo /etc/ntp-sync.conf > "$STAGE/DEBIAN/conffiles"

SECTION=user/system
DEPENDS="busybox"
DISPLAY_NAME="ntp-sync"
SHORT_DESC="Set the clock over NTP (works without a SIM card)"
LONG_DESC="Sets the system clock and the RTC with the busybox ntpd. Runs automatically when a network connection comes up (at most every 10 minutes), or by hand: sudo ntp-sync.
ntp-sync -n only shows the offset. Servers: /etc/ntp-sync.conf.
The Maemo setting for automatic time uses the cellular network time (NITZ), not NTP."
debpack_build
