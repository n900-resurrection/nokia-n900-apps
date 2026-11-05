#!/bin/bash
# Adjust a BusyBox .config for Maemo 5 (glibc 2.5, kernel 2.6.28). Usage: config.sh <path/.config>
set -euo pipefail
C="$1"
set_opt() {  # set_opt NAME y|n|value
    local n=$1 v=$2
    sed -i "/^\(# \)\?CONFIG_$n[= ]/d" "$C"
    case $v in
        n) echo "# CONFIG_$n is not set" >> "$C" ;;
        y) echo "CONFIG_$n=y" >> "$C" ;;
        *) echo "CONFIG_$n=$v" >> "$C" ;;
    esac
}
# Dynamic: a static glibc cannot do DNS / user lookups (NSS) without the shared libraries of the same
# version at runtime. The device has exactly the glibc 2.5 that the sysroot comes from.
set_opt STATIC n
set_opt EXTRA_LDLIBS '"/project/build/obj/busybox-shims.a"'
# UTIME_NOW/UTIME_OMIT are missing in the glibc 2.5 headers (values from the kernel ABI: (1<<30)-1 and (1<<30)-2).
set_opt EXTRA_CFLAGS '"-Os -include /project/scripts/maemo-compat.h -DUTIME_NOW=1073741823l -DUTIME_OMIT=1073741822l"'
# Needs newer kernel headers or libraries than the SDK has:
set_opt TC n
set_opt FEATURE_TC_INGRESS n
set_opt SELINUX n
set_opt PAM n
# libbb/capability.c includes <linux/capability.h>, whose old uid_t/gid_t types clash with glibc:
set_opt RUN_INIT n
set_opt NSLOOKUP n
set_opt FEATURE_NSLOOKUP_BIG n
set_opt FEATURE_NSLOOKUP_LONG_OPTIONS n
# No setns()/syncfs() on the 2.6.28 kernel:
set_opt NSENTER n
set_opt UNSHARE n
set_opt FEATURE_SYNC_FANCY n
# seedrng needs CLOCK_BOOTTIME (kernel 2.6.39) and getrandom():
set_opt SEEDRNG n
set_opt SHA1_HWACCEL n
set_opt SHA256_HWACCEL n
set_opt SETPRIV n
set_opt FEATURE_SETPRIV_DUMP n
set_opt FEATURE_SETPRIV_CAPABILITIES n
set_opt FEATURE_SETPRIV_CAPABILITY_NAMES n
# The ip applets need netlink headers (linux/can/netlink.h, IFA_F_DADFAILED) newer than the SDK has.
# The system busybox keeps providing ip, ifconfig and route for the network.
for o in IP IPADDR IPLINK IPROUTE IPTUNNEL IPRULE IPNEIGH FEATURE_IP_ADDRESS FEATURE_IP_LINK \
         FEATURE_IP_ROUTE FEATURE_IP_TUNNEL FEATURE_IP_RULE FEATURE_IP_NEIGH FEATURE_IP_RARE_PROTOCOLS; do
    set_opt $o n
done
# No IPv6 helpers to keep it small, no systemd/libbb extras:
set_opt FEATURE_UTMP n
set_opt FEATURE_WTMP n
# The TLS helper of wget is TLS 1.2 only and not a substitute for curl; keep wget but without SSL.
set_opt FEATURE_WGET_HTTPS n
set_opt SSL_CLIENT n
# Do not use the 2.6.28-missing syscalls where a fallback exists (getrandom is optional in 1.37).
set_opt INSTALL_NO_USR n
