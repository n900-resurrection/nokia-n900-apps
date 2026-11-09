#!/bin/bash
# Run apps/<app>/test.sh in the "emulated phone" (build/emu-root, see scripts/emu-root.sh): no phone needed. Run INSIDE the Workshop:
#   make emu-test APP="jq tmux"      or      scripts/emu-test.sh [--scripts] app...
# For every application: the .deb of build/deb (and the .deb of our own packages it depends on) is unpacked into the emulated phone, the status
# file for the dpkg stand-in is written, and tests/lib.sh + apps/<app>/test.sh run in a chroot under qemu-user like on the phone
# (a shell reading the script from stdin: sh -s). The chroot has the phone limits: kernel 2.6.28 reported, one CPU, a 1 MB /tmp.
#   --scripts   also run the postinst of the packages in the chroot (default: only unpack; most postinst scripts need the real system)
# Tests that need the real phone fail or are skipped here: the Hildon menu, Application Manager, ssh to localhost, the network of the phone, the
# system packages (htop 0.8.3 of Maemo), the device locale. That is the reason why this is a complement of `make test`, not its replacement.
set -uo pipefail
PROJ="${PROJ:-/project}"
R="$PROJ/build/emu-root"
SCRIPTS=0
[ "${1:-}" = "--scripts" ] && { SCRIPTS=1; shift; }
[ $# -gt 0 ] || { echo "usage: scripts/emu-test.sh [--scripts] app..." >&2; exit 2; }
"$PROJ/scripts/qemu-binfmt.sh" || exit 1
[ -f "$R/.emu-root" ] || "$PROJ/scripts/emu-root.sh" || exit 1

# the newest .deb of a package
deb_of() { ls -t "$PROJ"/build/deb/"$1"_*_armel.deb 2>/dev/null | head -1; }
declare -A DONE
install_deb() {   # install_deb <package> : unpack the .deb and (recursively) the .deb of its dependencies that are our packages
    local pkg=$1 deb dep
    [ -n "${DONE[$pkg]:-}" ] && return 0
    DONE[$pkg]=1
    deb=$(deb_of "$pkg")
    [ -n "$deb" ] || return 1
    for dep in $(dpkg-deb -f "$deb" Depends | tr ',' '\n' | sed 's/(.*//; s/|.*//; s/ //g'); do
        [ -n "$(deb_of "$dep")" ] && install_deb "$dep"
    done
    dpkg-deb -x "$deb" "$R"
    dpkg-deb -c "$deb" | awk '{print $6}' | sed 's/^\.//' | grep -v '/$' > "$R/var/lib/dpkg/emu/$pkg.list"
    { dpkg-deb -f "$deb" Package Version Architecture Depends Description | sed 's/^Description: /Description: /'; } > "$R/var/lib/dpkg/emu/$pkg.status.tmp"
    { echo "Package: $pkg"; echo "Status: install ok installed"; grep -v '^Package:' "$R/var/lib/dpkg/emu/$pkg.status.tmp"; } > "$R/var/lib/dpkg/emu/$pkg.status"
    rm -f "$R/var/lib/dpkg/emu/$pkg.status.tmp"
    if [ "$SCRIPTS" = 1 ]; then
        local d; d=$(mktemp -d "$PROJ/build/emu-ctl.XXXXXX"); dpkg-deb -e "$deb" "$d"
        if [ -x "$d/postinst" ]; then
            install -m 755 "$d/postinst" "$R/tmp/postinst-$pkg"
            sudo chroot "$R" /bin/sh -c "QEMU_UNAME=2.6.28 /tmp/postinst-$pkg configure" >/dev/null 2>&1 || echo "  (postinst of $pkg failed or is not supported here)"
            rm -f "$R/tmp/postinst-$pkg"
        fi
        rm -rf "$d"
    fi
    return 0
}

# the chroot shares the network of the Workshop; it only needs the resolver configuration of the host
cp -L /etc/resolv.conf "$R/etc/resolv.conf" 2>/dev/null || true
cp -L /etc/hosts "$R/etc/hosts" 2>/dev/null || true

fail=0
for app in "$@"; do
    t="$PROJ/apps/$app/test.sh"
    [ -f "$t" ] || { echo "== $app: no apps/$app/test.sh"; continue; }
    pkg=$(sed -n 's/^need_pkg \([^ ]*\).*/\1/p' "$t" | head -1); pkg="${pkg:-$app}"
    printf '\n== %s (package %s)\n' "$app" "$pkg"
    install_deb "$pkg" || { echo "no .deb of $pkg in build/deb: make debs APP=$app"; fail=$((fail+1)); continue; }
    cat "$PROJ/tests/lib.sh" "$t" | sudo env QEMU_UNAME=2.6.28 HOME=/root TERM=xterm LC_ALL=C PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin \
        unshare -m bash -c '
            R=$1; shift
            mount --bind /proc "$R/proc"; mount --rbind /dev "$R/dev"; mount -t tmpfs -o size=1m,mode=1777 tmpfs "$R/tmp"
            exec timeout 300 taskset -c 0 chroot "$R" /bin/sh -s' bash "$R"
    rc=$?
    [ $rc -eq 0 ] || fail=$((fail+1))
done
echo
[ $fail -eq 0 ] && echo "emulated phone: all suites passed" || echo "emulated phone: $fail suite(s) with failures"
[ $fail -eq 0 ]
