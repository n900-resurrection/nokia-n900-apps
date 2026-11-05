#!/bin/bash
# Package the built BusyBox as a .deb ("busybox37") for Maemo 5. Run INSIDE the Workshop after build.sh:
#   make -C apps/busybox deb
# Output: /project/build/deb/busybox37_<VERSION>-<REV>_armel.deb
# Lives next to the system busybox 1.23 in /opt/busybox37. Nothing in /bin or /usr/bin except the
# link /usr/bin/busybox37. The applet links are in /opt/busybox37/bin: put that directory in front of
# PATH to use the new versions, e.g.  PATH=/opt/busybox37/bin:$PATH
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=busybox37
VERSION="${VERSION:-1.37.0}"
OUT="$PROJ/build/out/busybox-$VERSION"
SRC="$PROJ/build/src/busybox-$VERSION"
STAGE="$PROJ/build/deb/stage-$PKG"
[ -x "$OUT/busybox" ] || { echo "Missing $OUT/busybox, run build.sh first (make build)"; exit 1; }

rm -rf "$STAGE"
mkdir -p "$STAGE/opt/$PKG/bin" "$STAGE/opt/$PKG/share/doc/$PKG" "$STAGE/usr/bin"
install -m 755 "$OUT/busybox" "$STAGE/opt/$PKG/bin/busybox"
# Applet links, relative so they work wherever the package is unpacked. The list comes from the
# binary itself (run with qemu-user in the workshop).
qemu-arm -L "$PROJ/sysroot" "$OUT/busybox" --list | while read -r a; do
    [ "$a" = busybox ] || ln -s busybox "$STAGE/opt/$PKG/bin/$a"
done
ln -s "../../opt/$PKG/bin/busybox" "$STAGE/usr/bin/busybox37"
install -m 644 "$SRC/LICENSE" "$STAGE/opt/$PKG/share/doc/$PKG/LICENSE"
cat > "$STAGE/opt/$PKG/share/doc/$PKG/README.Maemo" <<EOT
BusyBox $VERSION built for Maemo 5 (armel, glibc 2.5). Upstream: https://busybox.net/
Installed next to the system busybox 1.23 (/bin/busybox) and does not replace it.
Use: busybox37 <applet> ...  or  PATH=/opt/busybox37/bin:\$PATH
Differences from upstream defaults: no ip/ifconfig-related netlink applets (ip*, tc), nslookup, nsenter, unshare,
setpriv, seedrng, run-init (the old kernel or glibc lacks what they need); wget has no HTTPS (use curl).
Shims for utimensat/futimens are built in (apps/busybox/shims.c).
EOT
SECTION=user/system
DEPENDS="libc6 (>= 2.5)"
DISPLAY_NAME="BusyBox 1.37"
SHORT_DESC="BusyBox $VERSION (modern coreutils, ash, awk, sed, tar, ...)"
LONG_DESC="BusyBox $VERSION next to the system busybox 1.23. Applets are linked in /opt/busybox37/bin;
add that directory to PATH to use them. /usr/bin/busybox37 runs the multi-call binary."
debpack_build
