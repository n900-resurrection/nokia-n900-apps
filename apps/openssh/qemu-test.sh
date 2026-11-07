#!/bin/bash
# Emulation test of OpenSSH: sshd, ssh and sftp talk to each other over loopback under qemu-user. Run INSIDE the Workshop:
#   make -C apps/openssh qemu-test      (the package must be built first: make openssh)
# The phone is NOT used (agreed: a broken sshd must not cost the remote access).
#
# The sshd is rebuilt in a scratch copy of the source tree with two test-only changes, because qemu-user is a normal process whose own
# file descriptors and limits the sandbox of sshd would hit: closefrom() becomes a no-op and the setrlimit() calls of the rlimit sandbox
# do nothing. The shipped binaries are not changed. The ssh client and ssh-keygen are the shipped ones.
set -uo pipefail
VERSION="${VERSION:-10.6p2}"
PROJ=/project
O="$PROJ/build/out/openssh-$VERSION/root/opt/openssh"
SRC="$PROJ/build/src/openssh-$VERSION"
T="$PROJ/build/qtest"
W=$(mktemp -d /tmp/sshtest.XXXXXX)
Q="qemu-arm -L $PROJ/sysroot"
PASS=0; FAIL=0
check() {  # check <name> <condition command...>
    local n=$1; shift
    if "$@" >/dev/null 2>&1; then PASS=$((PASS+1)); echo "ok    $n"; else FAIL=$((FAIL+1)); echo "FAIL  $n"; fi
}
[ -x "$O/bin/ssh" ] && [ -d "$SRC" ] || { echo "Missing build, run: make openssh"; exit 1; }

echo "== test build of sshd"
export MAEMO_DEPS="$PROJ/build/deps/openssl-3.5.9:$PROJ/build/deps/zlib-1.3.2"
rm -rf "$PROJ/build/src/openssh-qtest" "$T"; cp -a "$SRC" "$PROJ/build/src/openssh-qtest"; mkdir -p "$T"
(cd "$PROJ/build/src/openssh-qtest" \
    && sed -i 's/closefrom(/(void)(/' sshd.c sshd-auth.c sshd-session.c \
    && sed -i 's/setrlimit(/0 * (long)(/' sandbox-rlimit.c \
    && touch sshd.c sshd-auth.c sshd-session.c sandbox-rlimit.c \
    && make sshd sshd-session sshd-auth > "$PROJ/build/qtest-build.log" 2>&1 \
    && cp sshd sshd-session sshd-auth "$T/") || { tail -20 "$PROJ/build/qtest-build.log"; exit 1; }

cd "$W"
mkdir w
# wrappers that start the ARM programs through qemu (sshd starts its helpers by path)
for n in sshd-session sshd-auth; do printf '#!/bin/sh\nexec qemu-arm -L %s %s/%s "$@"\n' "$PROJ/sysroot" "$T" "$n" > "w/$n"; done
printf '#!/bin/sh\nexec qemu-arm -L %s %s/bin/ssh "$@"\n' "$PROJ/sysroot" "$O" > w/ssh
printf '#!/bin/sh\nexec qemu-arm -L %s %s/libexec/sftp-server "$@"\n' "$PROJ/sysroot" "$O" > w/sftp-server
chmod +x w/*

echo "== keys and configuration"
check version sh -c "$Q $O/bin/ssh -V 2>&1 | grep -q 'OpenSSH_$VERSION, OpenSSL 3'"
check keygen-ed25519 $Q "$O/bin/ssh-keygen" -q -t ed25519 -N '' -f hostkey
check keygen-rsa $Q "$O/bin/ssh-keygen" -q -t rsa -b 2048 -N '' -f hostrsa
check keygen-client $Q "$O/bin/ssh-keygen" -q -t ed25519 -N '' -f client
cp client.pub authorized_keys
cat > sshd_config <<C
Port 2222
ListenAddress 127.0.0.1
HostKey $W/hostkey
HostKey $W/hostrsa
PidFile $W/sshd.pid
AuthorizedKeysFile $W/authorized_keys
StrictModes no
SshdSessionPath $W/w/sshd-session
SshdAuthPath $W/w/sshd-auth
Subsystem sftp $W/w/sftp-server
PasswordAuthentication no
LogLevel DEBUG1
C
check config $Q "$T/sshd" -t -f sshd_config

echo "== connections"
$Q "$T/sshd" -D -e -f sshd_config > sshd.log 2>&1 &
SSHD=$!
sleep 4
OPTS="-p 2222 -i client -o StrictHostKeyChecking=no -o UserKnownHostsFile=$W/kh -o IdentitiesOnly=yes"
check ssh-key-login sh -c "$W/w/ssh $OPTS 127.0.0.1 'echo remote-ok' 2>&1 | grep -q remote-ok"
check ssh-host-client sh -c "ssh $OPTS 127.0.0.1 'echo remote-ok' 2>&1 | grep -q remote-ok"
check ssh-wrong-key-refused sh -c "ssh-keygen -q -t ed25519 -N '' -f wrong && ! ssh -p 2222 -i wrong -o IdentitiesOnly=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=$W/kh -o BatchMode=yes 127.0.0.1 true"
echo hello-sftp > "$W/put.txt"
check sftp-put-get sh -c "printf 'put $W/put.txt $W/got.txt\nls\n' | $Q $O/bin/sftp -S $W/w/ssh -P 2222 -i client -o StrictHostKeyChecking=no -o UserKnownHostsFile=$W/kh -b - 127.0.0.1 >/dev/null 2>&1 && grep -q hello-sftp $W/got.txt"
kill "$SSHD" 2>/dev/null; kill "$(cat sshd.pid 2>/dev/null)" 2>/dev/null
cd /; rm -rf "$W"
echo; echo "openssh (qemu): $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
