#!/bin/bash
# Package wireguard-go + wg as a .deb for Maemo 5. Run INSIDE the Workshop after build.sh: make -C apps/wireguard-go deb
# Output: /project/build/deb/wireguard-go_<VERSION>-<REV>_armel.deb   (command line tools: no menu entry)
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=wireguard-go
VERSION="${VERSION:-0.0.20250522}"
OUT="$PROJ/build/out/$PKG-$VERSION"
STAGE="$PROJ/build/deb/stage-$PKG"
[ -x "$OUT/wireguard-go" ] && [ -x "$OUT/wg" ] || { echo "Missing build output in $OUT, run build.sh first (make build)"; exit 1; }

rm -rf "$STAGE"; mkdir -p "$STAGE/opt/wireguard-go/bin" "$STAGE/opt/wireguard-go/share/doc/wireguard-go" "$STAGE/usr/bin"
install -m 755 "$OUT/wireguard-go" "$OUT/wg" "$PROJ/apps/wireguard-go/wg-n900" "$STAGE/opt/wireguard-go/bin/"
for c in wireguard-go wg wg-n900; do ln -s "../../opt/wireguard-go/bin/$c" "$STAGE/usr/bin/$c"; done
install -m 644 "$OUT/LICENSE" "$STAGE/opt/wireguard-go/share/doc/wireguard-go/LICENSE"
cat > "$STAGE/opt/wireguard-go/share/doc/wireguard-go/README.Maemo" <<EOT
wireguard-go $VERSION and wg (wireguard-tools) for Maemo 5. The kernel 2.6.28 has no WireGuard module; wireguard-go runs the tunnel in user space over /dev/net/tun.
  wg genkey | tee private.key | wg pubkey         # key pair
  vi /home/user/wg0.conf                          # [Interface] PrivateKey, Address=10.0.0.2/32  [Peer] PublicKey, Endpoint=IP:51820, AllowedIPs, PersistentKeepalive=25
  wg-n900 up /home/user/wg0.conf                  # (as root) the interface wg0 and its routes
  wg show                                         # handshake and traffic
  wg-n900 down /home/user/wg0.conf
Keep the config private (chmod 600). DNS is not changed. Not part of the package: wg-quick (needs the full iproute2).
EOT

SECTION=user/network
DEPENDS="libc6 (>= 2.5)"
DISPLAY_NAME="WireGuard (wireguard-go)"
SHORT_DESC="wireguard-go $VERSION: WireGuard VPN in user space, with wg and wg-n900"
LONG_DESC="WireGuard VPN for the N900: wireguard-go $VERSION (the Go implementation, static) with the wg tool and the helper wg-n900 up|down, which sets
up the interface and routes with the busybox ip of the phone. The kernel 2.6.28 has no WireGuard module, so everything runs in user space over /dev/net/tun.
Needs a WireGuard server (a home router, a VPS). See /opt/wireguard-go/share/doc/wireguard-go/README.Maemo. Upstream: https://www.wireguard.com"
MAINTAINER="elPytel (build of upstream wireguard-go and wireguard-tools by Jason A. Donenfeld)"
debpack_build
