#!/bin/bash
# Run on the HOST: copy the Hildon runtime files that the SDK sysroot lacks from the phone into ./sysroot
# (theme "beta" = the Maemo 5 look, Nokia fonts, icons, pango modules, gtk configuration, Python 2.5 with PyGTK and Hildon bindings). ~100 MB, one time.
# Then scripts/hildon-run.sh can show GTK2/Hildon programs on a virtual screen on the PC.
set -euo pipefail
cd "$(dirname "$0")/.."
DEVICE="${DEVICE:-n900}"
ssh "$DEVICE" 'tar -C / -cf - usr/share/themes/beta usr/share/themes/alpha usr/share/fonts etc/fonts usr/share/icons/hicolor etc/gtk-2.0 etc/hildon usr/lib/pango etc/pango usr/lib/gtk-2.0 usr/bin/python2.5 usr/lib/python2.5 usr/lib/pymodules usr/lib/libpyglib-2.0-python2.5.so* usr/lib/libpython2.5.so* usr/lib/pyshared usr/share/pyshared usr/lib/python-support usr/share/python-support 2>/dev/null; true' \
    | tar -C sysroot -xf -
echo "Hildon overlay copied into sysroot/ ($(du -sh sysroot/usr/share/themes | cut -f1) of themes)"
# qemu-user resolves absolute symlinks on the host, not inside the sysroot: replace the symlinks of the Python 2.5 modules
# (Debian keeps the real files in /usr/lib/pyshared) by copies.
for l in $(find sysroot/usr/lib/pymodules -type l); do
    t=$(readlink "$l")
    case "$t" in /*) [ -e "sysroot$t" ] && { rm "$l"; cp -a "sysroot$t" "$l"; } ;; esac
done
# Libraries that the Python 2.5 GTK/Hildon modules need and the SDK sysroot does not have: ask the phone (ldd) and copy them.
miss=""
for so in /usr/lib/pymodules/python2.5/_dbus_bindings.so /usr/lib/pymodules/python2.5/_dbus_glib_bindings.so /usr/lib/python2.5/site-packages/osso.so /usr/lib/python2.5/site-packages/conic.so /usr/lib/python2.5/lib-dynload/_sqlite3.so /usr/lib/python2.5/site-packages/hildon.so /usr/lib/pymodules/python2.5/gtk-2.0/gtk/_gtk.so /usr/lib/pymodules/python2.5/gtk-2.0/gtk/gdk.so; do
    for l in $(ssh "$DEVICE" "ldd $so" 2>/dev/null | awk '/=>/ {print $3}'); do
        [ -e "sysroot$l" ] || miss="$miss ${l#/}"
    done
done
[ -z "${miss// /}" ] || ssh "$DEVICE" "tar -C / -chf - $miss 2>/dev/null; true" | tar -C sysroot -xf -
ssh "$DEVICE" 'tar -C / -chf - usr/lib/libffi.so.5 usr/lib/libpyglib-2.0-python2.5.so.0 2>/dev/null; true' | tar -C sysroot -xf -
