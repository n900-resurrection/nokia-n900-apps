#!/bin/bash
# Package the built OpenSSH as a .deb for Maemo 5. Run INSIDE the Workshop after build.sh: make -C apps/openssh deb
# Output: /project/build/deb/openssh_<VERSION>-<REV>_armel.deb
#
# Everything lives in /opt/openssh; the system OpenSSH 5.1 (/usr/bin/ssh, /usr/sbin/sshd) is not touched. The new client is
# reachable as ssh-modern, scp-modern, sftp-modern and ssh-keygen-modern. sshd is NOT started by the package: run it by hand
# (/opt/openssh/sbin/sshd, port 2222 by default) or replace the system one yourself once you trust it.
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=openssh
VERSION="${VERSION:-10.6p2}"
OUT="$PROJ/build/out/openssh-$VERSION"
STAGE="$PROJ/build/deb/stage-$PKG"
[ -x "$OUT/root/opt/openssh/bin/ssh" ] || { echo "Missing build output in $OUT, run build.sh first (make build)"; exit 1; }

rm -rf "$STAGE"; mkdir -p "$STAGE/usr/bin"
cp -a "$OUT/root/." "$STAGE/"
# the build leaves an empty privsep directory out of the tree: sshd chroots into it (it must be owned by root, not writable)
mkdir -p "$STAGE/opt/openssh/var/empty"
rm -f "$STAGE"/opt/openssh/etc/ssh_host_* 2>/dev/null || true
# Pruned to keep the package small (each program carries its own static OpenSSL): no host-based authentication, PKCS#11 and FIDO helpers
# (FIDO is not built at all), no ssh-keyscan.
rm -f "$STAGE"/opt/openssh/libexec/{ssh-keysign,ssh-pkcs11-helper,ssh-sk-helper} "$STAGE/opt/openssh/bin/ssh-keyscan"
for c in ssh scp sftp ssh-keygen; do ln -s "../../opt/openssh/bin/$c" "$STAGE/usr/bin/$c-modern"; done

# Default configuration: a safe one, because sshd of a phone on mobile data is reachable from the internet.
cat > "$STAGE/opt/openssh/etc/sshd_config" <<'EOT'
# sshd of the openssh package (in /opt/openssh). Start it by hand: /opt/openssh/sbin/sshd
# A different port than the system sshd (22), so both can run side by side.
Port 2222
HostKey /opt/openssh/etc/ssh_host_ed25519_key
HostKey /opt/openssh/etc/ssh_host_rsa_key
PidFile /var/run/sshd-modern.pid
# Keys only, no root: put your public key into /home/user/.ssh/authorized_keys first (chmod 700 .ssh, chmod 600 authorized_keys).
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
AllowUsers user
AuthorizedKeysFile .ssh/authorized_keys
Subsystem sftp /opt/openssh/libexec/sftp-server
EOT

mkdir -p "$STAGE/DEBIAN"
cat > "$STAGE/DEBIAN/postinst" <<'EOT'
#!/bin/sh
# Host keys (once) and the user the privilege separation needs. Nothing is started.
set -e
E=/opt/openssh/etc
chown root:root /opt/openssh/var/empty
chmod 755 /opt/openssh/var/empty
[ -f $E/ssh_host_ed25519_key ] || /opt/openssh/bin/ssh-keygen -q -t ed25519 -N '' -f $E/ssh_host_ed25519_key
[ -f $E/ssh_host_rsa_key ] || /opt/openssh/bin/ssh-keygen -q -t rsa -b 3072 -N '' -f $E/ssh_host_rsa_key
grep -q '^sshd:' /etc/passwd || adduser -S -D -H -h /opt/openssh/var/empty -s /bin/false sshd >/dev/null 2>&1 || true
exit 0
EOT
cat > "$STAGE/DEBIAN/postrm" <<'EOT'
#!/bin/sh
# On purge the host keys (created by postinst, not part of the package) go too.
[ "$1" = purge ] && rm -f /opt/openssh/etc/ssh_host_* || true
exit 0
EOT
chmod 755 "$STAGE/DEBIAN/postinst" "$STAGE/DEBIAN/postrm"

SECTION=user/network
DEPENDS="libc6 (>= 2.5)"
DISPLAY_NAME="OpenSSH $VERSION"
SHORT_DESC="OpenSSH $VERSION client and server (modern ciphers, OpenSSL 3), alongside the system one"
LONG_DESC="OpenSSH $VERSION portable for Maemo 5 with a private static OpenSSL 3 and zlib, installed in /opt/openssh. The system OpenSSH 5.1 stays as it is.
Client: ssh-modern, scp-modern, sftp-modern, ssh-keygen-modern (ed25519 keys, modern key exchange, works with current servers).
Server: /opt/openssh/sbin/sshd on port 2222, keys only, no root login (see /opt/openssh/etc/sshd_config). It is not started by the package.
Not tested on a real N900 when it was packaged: the sandbox of sshd is the rlimit one (the 2.6.28 kernel has no seccomp filter)."
MAINTAINER="elPytel (build of upstream OpenSSH by the OpenBSD project)"
debpack_build
