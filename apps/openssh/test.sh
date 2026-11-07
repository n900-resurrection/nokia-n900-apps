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
summary
