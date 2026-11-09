#!/bin/bash
# Create (or refresh) the root file system of the "emulated phone": build/emu-root. Run INSIDE the Workshop:  scripts/emu-root.sh [--reset]
# It is the SDK sysroot (glibc 2.5, libraries) plus what a shell session of the phone has: busybox with its applets, /etc/passwd, /home/user,
# and two small stand-ins for tools that need the real system: dpkg (-s, -l, -L over a status directory) and ldd (the loader of glibc in trace mode).
# ARM programs run in it through qemu-user (binfmt_misc, registered by the package qemu-user-static; the chroot needs the static one).
# scripts/emu-test.sh installs packages into it and runs apps/<app>/test.sh in it. build/emu-root is not in git (about 400 MB).
set -euo pipefail
PROJ="${PROJ:-/project}"
R="$PROJ/build/emu-root"
BB="$PROJ/build/out/busybox-1.37.0/busybox"
[ "${1:-}" = "--reset" ] && { [ -n "$R" ] && sudo rm -rf "$R"; }
[ -x "$BB" ] || { echo "Missing $BB, run: make busybox" >&2; exit 1; }
[ -d "$PROJ/sysroot/usr/include" ] || { echo "Missing the sysroot, run: make sysroot" >&2; exit 1; }
command -v qemu-arm-static >/dev/null || { echo "qemu-user-static is not installed (sudo apt install qemu-user-static)" >&2; exit 1; }

if [ ! -f "$R/.emu-root" ]; then
    echo "== creating $R (copy of the sysroot, one time)"
    mkdir -p "$R"
    cp -a "$PROJ/sysroot/." "$R/"
    : > "$R/.emu-root"
fi

chmod -R u+w "$R"     # the files of the SDK are read-only
mkdir -p "$R"/{proc,dev,tmp,root,home/user,var/lib/dpkg/emu,opt,etc,usr/local/bin}
chmod 1777 "$R/tmp"
# busybox and its applets (links are relative to the root of the emulated phone; an applet that the sysroot already has is kept)
install -m 755 "$BB" "$R/bin/busybox"
qemu-arm-static -L "$PROJ/sysroot" "$BB" --list-full | while read -r p; do
    [ -e "$R/$p" ] || [ -L "$R/$p" ] || { mkdir -p "$R/$(dirname "$p")"; ln -s /bin/busybox "$R/$p"; }
done
[ -e "$R/bin/sh" ] || ln -s /bin/busybox "$R/bin/sh"
grep -q '^root:' "$R/etc/passwd" 2>/dev/null || printf 'root:x:0:0:root:/root:/bin/sh\nuser:x:29999:29999:user:/home/user:/bin/sh\n' > "$R/etc/passwd"
grep -q '^root:' "$R/etc/group" 2>/dev/null || printf 'root:x:0:\nusers:x:100:\nuser:x:29999:\n' > "$R/etc/group"
# dpkg stand-in: the status files are written by scripts/emu-test.sh when it installs a package
rm -f "$R/usr/bin/dpkg"
cat > "$R/usr/bin/dpkg" <<'EOF'
#!/bin/sh
# stand-in for dpkg in the emulated phone: -s PKG, -l [PKG], -L PKG (the data comes from /var/lib/dpkg/emu)
D=/var/lib/dpkg/emu
case "$1" in
    -s|--status)
        [ -f "$D/$2.status" ] || { echo "dpkg: package '$2' is not installed and no information is available" >&2; exit 1; }
        cat "$D/$2.status" ;;
    -L|--listfiles)
        [ -f "$D/$2.list" ] || { echo "dpkg: package '$2' is not installed" >&2; exit 1; }
        cat "$D/$2.list" ;;
    -l|--list)
        for f in "$D"/*.status; do [ -e "$f" ] || continue
            p=$(basename "$f" .status); [ -z "$2" ] || [ "$p" = "$2" ] || continue
            printf 'ii  %-24s %s\n' "$p" "$(sed -n 's/^Version: //p' "$f")"; done ;;
    *) echo "dpkg (emulated phone): unsupported: $*" >&2; exit 2 ;;
esac
EOF
chmod 755 "$R/usr/bin/dpkg"
# ldd stand-in: the glibc loader in trace mode lists the libraries ("not found" for the missing ones), like the real ldd
rm -f "$R/usr/bin/ldd"
cat > "$R/usr/bin/ldd" <<'EOF'
#!/bin/sh
for f in "$@"; do
    [ $# -gt 1 ] && echo "$f:"
    LD_TRACE_LOADED_OBJECTS=1 /lib/ld-linux.so.3 "$f" 2>&1
done
EOF
chmod 755 "$R/usr/bin/ldd"
echo "emulated phone ready: $R ($(du -sh "$R" | cut -f1))"
