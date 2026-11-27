TEST_NAME=openssh
# Not installed on purpose: the package is not tested on the phone (see make -C apps/openssh qemu-test). Installed: only safe checks.
if ! dpkg -s openssh 2>/dev/null | grep -q '^Status: install ok installed'; then
    skip openssh "package not installed (emulation test: make -C apps/openssh qemu-test)"
    summary
    exit 0
fi
ok no-missing-libs sh -c '! ldd /opt/openssh/bin/ssh 2>&1 | grep -q "not found"'
t version 'OpenSSH_10.6p2, OpenSSL 3.5.9 29 Sep 2026' sh -c 'ssh-modern -V'
ok config-valid /opt/openssh/sbin/sshd -t -f /opt/openssh/etc/sshd_config
ok host-keys test -s /opt/openssh/etc/ssh_host_ed25519_key
# A real login on the loopback only (port 2299, a throw-away key and configuration, nothing reachable from the network). This found that the key exchange died with
# "Invalid argument" in the sandboxed process (poll() with a limit of 0 files, see build.sh) and keeps it from coming back.
tmpdir
chmod 777 "$TESTDIR"
loopback_login() {
    K="$TESTDIR/key"
    su user -c "/opt/openssh/bin/ssh-keygen -q -t ed25519 -N '' -f $K" || return
    cp "$K.pub" "$TESTDIR/authorized"; chmod 644 "$TESTDIR/authorized"
    printf '%s\n' "Port 2299" "ListenAddress 127.0.0.1" "HostKey /opt/openssh/etc/ssh_host_ed25519_key" "PidFile $TESTDIR/sshd.pid" "AuthorizedKeysFile $TESTDIR/authorized" \
        "StrictModes no" "PasswordAuthentication no" "AllowUsers user" > "$TESTDIR/sshd_config"
    /opt/openssh/sbin/sshd -f "$TESTDIR/sshd_config" -E "$TESTDIR/sshd.log" || return
    sleep 1
    out=$(su user -c "/opt/openssh/bin/ssh -p 2299 -i $K -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR user@127.0.0.1 'echo login-ok'" 2>&1)
    kill "$(cat "$TESTDIR/sshd.pid")" 2>/dev/null
    echo "$out"
}
contains loopback-login "login-ok" loopback_login
summary
