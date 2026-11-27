#!/bin/bash
# Package the built OpenSSH as a .deb for Maemo 5. Run INSIDE the Workshop after build.sh: make -C apps/openssh deb
# Output: /project/build/deb/openssh_<VERSION>-<REV>_armel.deb
#
# Two kinds of the package, chosen by the number in the revision (1maemoN):
#   N <= 5  PARALLEL: everything lives in /opt/openssh and the system OpenSSH 5.1 (/usr/bin/ssh, /usr/sbin/sshd, the upstart job sshd) is not touched. The new
#           client is reachable as ssh-modern, scp-modern, sftp-modern and ssh-keygen-modern. sshd is NOT started by the package (by hand:
#           /opt/openssh/sbin/sshd, port 2222). openssh-switch (in /opt/openssh/sbin) moves the server to port 22 for a trial with a safety timer.
#   N >= 6  REPLACING: the same files, and in addition it takes the place of openssh-client, openssh-server and openssh-common (Provides, Replaces and
#           Conflicts: dpkg removes the old packages when it installs this one): /usr/bin/ssh and the others are links into /opt/openssh, the upstart job
#           /etc/event.d/sshd starts the new server (port 22, respawn), /etc/init.d/ssh is kept for the SSH switch of gothi. Install it only after
#           `openssh-switch trial` and `confirm` proved that logins work: the old server is gone when it is installed.
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=openssh
VERSION="${VERSION:-10.6p2}"
OUT="$PROJ/build/out/openssh-$VERSION"
STAGE="$PROJ/build/deb/stage-$PKG"
HERE="$PROJ/apps/openssh"
N="${REV#1maemo}"
case "$N" in ''|*[!0-9]*) echo "REV must look like 1maemo5 (got $REV)"; exit 1;; esac
REPLACING=0; [ "$N" -ge 6 ] && REPLACING=1
[ -x "$OUT/root/opt/openssh/bin/ssh" ] || { echo "Missing build output in $OUT, run build.sh first (make build)"; exit 1; }

rm -rf "$STAGE"; mkdir -p "$STAGE/usr/bin"
cp -a "$OUT/root/." "$STAGE/"
# the build leaves an empty privsep directory out of the tree: sshd chroots into it (it must be owned by root, not writable)
mkdir -p "$STAGE/opt/openssh/var/empty"
rm -f "$STAGE"/opt/openssh/etc/ssh_host_* 2>/dev/null || true
# the sshd_config of upstream (everything commented out: passwords allowed!) must not be in the package: postinst copies sshd_config.default (below) when
# there is no sshd_config, and a file of the package would be there already
rm -f "$STAGE/opt/openssh/etc/sshd_config"
# Pruned to keep the package small (each program carries its own static OpenSSL): no host-based authentication, PKCS#11 and FIDO helpers
# (FIDO is not built at all), no ssh-keyscan.
rm -f "$STAGE"/opt/openssh/libexec/{ssh-keysign,ssh-pkcs11-helper,ssh-sk-helper} "$STAGE/opt/openssh/bin/ssh-keyscan"
for c in ssh scp sftp ssh-keygen; do ln -s "../../opt/openssh/bin/$c" "$STAGE/usr/bin/$c-modern"; done

# openssh-switch: the move of the server to port 22 with a safety timer (see the script)
install -m 755 "$HERE/switch/openssh-switch" "$STAGE/opt/openssh/sbin/openssh-switch"
mkdir -p "$STAGE/usr/sbin"; ln -s ../../opt/openssh/sbin/openssh-switch "$STAGE/usr/sbin/openssh-switch"

# The default configuration is shipped as sshd_config.default and copied by postinst when there is no sshd_config (or only the one of the parallel kind):
# a file that is not part of the package keeps the changes of the owner. A safe one, because sshd of a phone on mobile data is reachable from the internet.
KEYS='# Keys only: put your public key into /home/user/.ssh/authorized_keys first (chmod 700 .ssh, chmod 600 authorized_keys). root may log in with a key too (the
# tools that deploy packages use it) but never with a password; to forbid root completely, set PermitRootLogin no and drop root from AllowUsers.
PermitRootLogin prohibit-password
PasswordAuthentication no
KbdInteractiveAuthentication no
AllowUsers user root
AuthorizedKeysFile .ssh/authorized_keys
Subsystem sftp /opt/openssh/libexec/sftp-server'
if [ "$REPLACING" = 1 ]; then
    cat > "$STAGE/opt/openssh/etc/sshd_config.default" <<EOT
# sshd of the openssh package (replaces the system OpenSSH): started by the upstart job /etc/event.d/sshd, port 22.
Port 22
HostKey /opt/openssh/etc/ssh_host_ed25519_key
HostKey /opt/openssh/etc/ssh_host_rsa_key
PidFile /var/run/sshd.pid
$KEYS
EOT
else
    cat > "$STAGE/opt/openssh/etc/sshd_config.default" <<EOT
# sshd of the openssh package (in /opt/openssh). Start it by hand: /opt/openssh/sbin/sshd
# A different port than the system sshd (22), so both can run side by side.
Port 2222
HostKey /opt/openssh/etc/ssh_host_ed25519_key
HostKey /opt/openssh/etc/ssh_host_rsa_key
PidFile /var/run/sshd-modern.pid
$KEYS
EOT
fi

if [ "$REPLACING" = 1 ]; then
    mkdir -p "$STAGE/etc/event.d" "$STAGE/etc/init.d" "$STAGE/usr/sbin" "$STAGE/usr/lib/openssh"
    for c in ssh scp sftp ssh-keygen ssh-add ssh-agent; do ln -sf "../../opt/openssh/bin/$c" "$STAGE/usr/bin/$c"; done
    ln -s ssh "$STAGE/usr/bin/slogin"
    ln -s ../../opt/openssh/sbin/sshd "$STAGE/usr/sbin/sshd"
    ln -s ../../../opt/openssh/libexec/sftp-server "$STAGE/usr/lib/openssh/sftp-server"
    ln -s ../../opt/openssh/libexec/sftp-server "$STAGE/usr/lib/sftp-server"
    # the upstart job (the old package has one with the same name): runs sshd in the foreground and starts it again when it dies. A broken
    # configuration stops the job in pre-start instead of making it respawn for ever. The old job lived in the root file system; this one needs /opt.
    cat > "$STAGE/etc/event.d/sshd" <<'EOT'
start on stopped rcS

console output

respawn

pre-start script
    # /opt is a bind mount of /home/opt, and /home is mounted late (the job rcS-late, which starts on `started hal`): at the event that starts this
    # job the server may not be there yet. Wait for it (up to 3 minutes) instead of failing at boot and leaving the phone without ssh.
    n=0
    while [ ! -x /opt/openssh/sbin/sshd ] && [ $n -lt 180 ]; do
        sleep 1
        n=$((n + 1))
    done
    [ -x /opt/openssh/sbin/sshd ] || exit 1
    if [ ! -d /var/run/sshd ] ; then
        mkdir /var/run/sshd
        chmod 755 /var/run/sshd
    fi
    /opt/openssh/sbin/sshd -t || exit 1
end script

exec /opt/openssh/sbin/sshd -D
EOT
    # /etc/init.d/ssh keeps the old interface (the SSH switch of gothi and administrators use it) on top of the upstart job
    cat > "$STAGE/etc/init.d/ssh" <<'EOT'
#! /bin/sh
# /etc/init.d/ssh: start and stop the ssh server (OpenSSH in /opt/openssh) through the upstart job sshd
export PATH="${PATH:+$PATH:}/usr/sbin:/sbin"
case "$1" in
  start)   echo -n "Starting ssh server: sshd"; start sshd > /dev/null 2>&1; echo "." ;;
  stop)    echo -n "Stopping ssh server: sshd"; stop sshd > /dev/null 2>&1; echo "." ;;
  restart|force-restart) echo -n "Restarting ssh server: sshd"; /opt/openssh/sbin/sshd -t || exit 1; stop sshd > /dev/null 2>&1; start sshd > /dev/null 2>&1; echo "." ;;
  reload|force-reload)   /opt/openssh/sbin/sshd -t || exit 1; kill -HUP "$(cat /var/run/sshd.pid)" ;;
  status)  status sshd ;;
  *) echo "Usage: /etc/init.d/ssh {start|stop|restart|reload|status}"; exit 1 ;;
esac
exit 0
EOT
    chmod 755 "$STAGE/etc/init.d/ssh"
fi

mkdir -p "$STAGE/DEBIAN"
cat > "$STAGE/DEBIAN/postinst" <<EOT
#!/bin/sh
# Host keys (once), the user the privilege separation needs, the configuration (only when there is none of the right kind).
set -e
E=/opt/openssh/etc
chown root:root /opt/openssh/var/empty
chmod 755 /opt/openssh/var/empty
[ -f \$E/ssh_host_ed25519_key ] || /opt/openssh/bin/ssh-keygen -q -t ed25519 -N '' -f \$E/ssh_host_ed25519_key
[ -f \$E/ssh_host_rsa_key ] || /opt/openssh/bin/ssh-keygen -q -t rsa -b 3072 -N '' -f \$E/ssh_host_rsa_key
grep -q '^sshd:' /etc/passwd || adduser -S -D -H -h /opt/openssh/var/empty -s /bin/false sshd >/dev/null 2>&1 || true
REPLACING=$REPLACING
if [ ! -f \$E/sshd_config ]; then
    cp \$E/sshd_config.default \$E/sshd_config
elif [ "\$REPLACING" = 1 ] && grep -q '^# sshd of the openssh package.*Start it by hand' \$E/sshd_config; then
    # the configuration of the parallel kind (port 2222) becomes the one of the replacing kind (port 22); the old one is kept next to it
    cp \$E/sshd_config \$E/sshd_config.parallel
    cp \$E/sshd_config.default \$E/sshd_config
fi
if [ "\$REPLACING" = 1 ]; then
    # the server of the trial (started by openssh-switch, not by upstart) is replaced by the upstart job; sessions stay open. Only a configuration that
    # passes sshd -t is started: with a broken one the old server is gone and nothing would listen.
    if /opt/openssh/sbin/sshd -t; then
        p=\$(cat /var/run/sshd.pid 2>/dev/null || true)
        if [ -n "\$p" ] && tr '\0' ' ' < /proc/\$p/cmdline 2>/dev/null | grep -q /opt/openssh/sbin/sshd; then kill "\$p" || true; sleep 2; fi
        stop sshd > /dev/null 2>&1 || true
        start sshd > /dev/null 2>&1 || true
        echo "openssh: the ssh server runs as the upstart job sshd on port 22 (openssh-switch status)"
    else
        echo "openssh: WARNING: /opt/openssh/etc/sshd_config does not pass sshd -t, the server was NOT started. Fix it and run: start sshd" >&2
    fi
else
    echo "openssh: not started; the server of the system keeps running on port 22 (openssh-switch check / trial moves it)"
fi
exit 0
EOT
cat > "$STAGE/DEBIAN/prerm" <<EOT
#!/bin/sh
# The replacing kind stops the job when it is removed (nothing would start the server again); the parallel kind has nothing running to stop.
[ $REPLACING = 1 ] && [ "\$1" = remove ] && { stop sshd > /dev/null 2>&1 || true; }
exit 0
EOT
cat > "$STAGE/DEBIAN/postrm" <<'EOT'
#!/bin/sh
# On purge the host keys and the configuration (created by postinst, not part of the package) go too.
[ "$1" = purge ] && rm -f /opt/openssh/etc/ssh_host_* /opt/openssh/etc/sshd_config /opt/openssh/etc/sshd_config.parallel || true
exit 0
EOT
chmod 755 "$STAGE/DEBIAN/postinst" "$STAGE/DEBIAN/prerm" "$STAGE/DEBIAN/postrm"

SECTION=user/network
DEPENDS="libc6 (>= 2.5)"
DISPLAY_NAME="OpenSSH $VERSION"
if [ "$REPLACING" = 1 ]; then
    PROVIDES="openssh-client, openssh-server, openssh-common"
    CONFLICTS="openssh-client, openssh-server, openssh-common"
    REPLACES="openssh-client, openssh-server, openssh-common"
    SHORT_DESC="OpenSSH $VERSION client and server (modern ciphers, OpenSSL 3), replaces the system OpenSSH 5.1"
    LONG_DESC="OpenSSH $VERSION portable for Maemo 5 with a private static OpenSSL 3 and zlib, installed in /opt/openssh. It REPLACES the system OpenSSH 5.1 (openssh-client, openssh-server, openssh-common are removed when it is installed).
Install it only after the server was tried with openssh-switch (trial, then confirm): it needs your public key in /home/user/.ssh/authorized_keys or /root/.ssh/authorized_keys, because passwords are refused.
Client: ssh, scp, sftp, ssh-keygen, ssh-add, ssh-agent (ed25519 keys, modern key exchange, works with current servers). Server: the upstart job sshd on port 22, keys only, root only with a key (see /opt/openssh/etc/sshd_config).
The sandbox of sshd is the rlimit one (the 2.6.28 kernel has no seccomp filter); not included: ssh-keyscan, ssh-copy-id."
else
    SHORT_DESC="OpenSSH $VERSION client and server (modern ciphers, OpenSSL 3), alongside the system one"
    LONG_DESC="OpenSSH $VERSION portable for Maemo 5 with a private static OpenSSL 3 and zlib, installed in /opt/openssh. The system OpenSSH 5.1 stays as it is.
Client: ssh-modern, scp-modern, sftp-modern, ssh-keygen-modern (ed25519 keys, modern key exchange, works with current servers).
Server: /opt/openssh/sbin/sshd on port 2222, keys only, root only with a key (see /opt/openssh/etc/sshd_config). It is not started by the package.
openssh-switch moves the server to port 22 for a trial with a safety timer (the old server comes back unless you confirm).
The sandbox of sshd is the rlimit one (the 2.6.28 kernel has no seccomp filter)."
fi
MAINTAINER="elPytel (build of upstream OpenSSH by the OpenBSD project)"
debpack_build
