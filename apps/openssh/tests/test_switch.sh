#!/bin/bash
# Tests of switch/openssh-switch on a computer with fake `start`, `stop`, `netstat` and a fake sshd (no phone, nothing real is started):  bash tests/test_switch.sh
HERE=$(cd "$(dirname "$0")" && pwd)
SW="$HERE/../switch/openssh-switch"
pass=0; failed=0
T=$(mktemp -d); trap 'pkill -f "$T" 2>/dev/null; rm -rf "$T"' EXIT
ok()   { pass=$((pass + 1)); echo "ok    $1"; }
bad()  { failed=$((failed + 1)); echo "FAIL  $1"; [ -n "$2" ] && echo "      $2"; [ -s "$T/out" ] && sed "s/^/      | /" "$T/out"; }
check() { if eval "$2"; then ok "$1"; else bad "$1" "$2"; fi; }

mkdir -p "$T/bin" "$T/run" "$T/opt/openssh/sbin" "$T/opt/openssh/etc" "$T/etc/ssh" "$T/usr/sbin" "$T/keys"
echo "old sshd binary" > "$T/usr/sbin/sshd"; echo "old config" > "$T/etc/ssh/sshd_config"
printf 'PasswordAuthentication no\nPort 2222\n' > "$T/opt/openssh/etc/sshd_config"
echo "ssh-ed25519 AAAA key1" > "$T/keys/user"; printf 'ssh-ed25519 AAAA key1\nssh-rsa BBBB key2\n' > "$T/keys/root"

# fakes: the old server is the upstart job `sshd` (a sleeping shell that writes the pid file), the new one is a script that starts such a shell
cat > "$T/bin/netstat" <<EOT
#!/bin/sh
[ -e "$T/listen22" ] && echo "tcp        0      0 0.0.0.0:22              0.0.0.0:*               LISTEN"
exit 0
EOT
cat > "$T/bin/status" <<EOT
#!/bin/sh
if [ -e "$T/job" ]; then echo "sshd (start) running, process 1"; else echo "sshd (stop) waiting"; fi
EOT
cat > "$T/bin/start" <<EOT
#!/bin/sh
echo "start \$1" >> "$T/calls"
[ -e "$T/job" ] && exit 0
touch "$T/job" "$T/listen22"
setsid sh -c 'echo \$\$ > "$T/run/sshd.pid"; while :; do sleep 1; done # old sshd $T' > /dev/null 2>&1 < /dev/null &
sleep 1
EOT
cat > "$T/bin/stop" <<EOT
#!/bin/sh
echo "stop \$1" >> "$T/calls"
rm -f "$T/job" "$T/listen22"
p=\$(cat "$T/run/sshd.pid" 2>/dev/null); [ -n "\$p" ] && kill "\$p" 2>/dev/null
rm -f "$T/run/sshd.pid"
exit 0
EOT
cat > "$T/opt/openssh/sbin/sshd" <<EOT
#!/bin/sh
for a in "\$@"; do [ "\$a" = -t ] && { [ -e "$T/bad_config" ] && exit 1; exit 0; }; done
[ -e "$T/bad_start" ] && exit 1
pf=""; for a in "\$@"; do case \$a in PidFile=*) pf=\${a#PidFile=};; esac; done
touch "$T/listen22"
setsid sh -c "trap \\"rm -f $T/listen22; exit\\" TERM; echo \\\$\\\$ > '\$pf'; while :; do sleep 1; done # $T/opt/openssh/sbin/sshd" > /dev/null 2>&1 < /dev/null &
sleep 1
exit 0
EOT
chmod 755 "$T"/bin/* "$T/opt/openssh/sbin/sshd"

export PATH="$T/bin:$PATH" NEW_SSHD="$T/opt/openssh/sbin/sshd" NEW_CONF="$T/opt/openssh/etc/sshd_config" PIDFILE="$T/run/sshd.pid" RUN="$T/run" \
       LOG="$T/log" BACKUP="$T/backup.tgz" AUTH_FILES="$T/keys/user $T/keys/root" OLD_FILES="$T/etc/ssh $T/usr/sbin/sshd" SKIP_ROOT_CHECK=1
sw() { ${SWSH:-sh} "$SW" "$@"; }
old_running() { [ -e "$T/job" ] && [ -e "$T/listen22" ] && grep -q sshd "/proc/$(cat "$T/run/sshd.pid")/cmdline" 2>/dev/null && ! tr '\0' ' ' < "/proc/$(cat "$T/run/sshd.pid")/cmdline" | grep -q "$T/opt/openssh"; }
new_running() { p=$(cat "$T/run/sshd.pid" 2>/dev/null); [ -n "$p" ] && kill -0 "$p" 2>/dev/null && tr '\0' ' ' < "/proc/$p/cmdline" | grep -q "$T/opt/openssh/sbin/sshd"; }
guard_running() { g=$(cat "$T/run/openssh-switch.guard" 2>/dev/null); [ -n "$g" ] && kill -0 "$g" 2>/dev/null; }

"$T/bin/start" sshd
check "the fake old server runs" old_running

# ---- check
check "check passes when everything is in place" 'sw check >/dev/null'
check "check says how many keys there are" 'sw check | grep -q "keys/root: 2 keys"'
touch "$T/bad_config"; check "check fails when sshd -t fails" '! sw check >/dev/null'; rm "$T/bad_config"
mv "$T/keys/user" "$T/keys/user.x"; mv "$T/keys/root" "$T/keys/root.x"
check "check fails without any authorized key" '! sw check >/dev/null'
mv "$T/keys/user.x" "$T/keys/user"; mv "$T/keys/root.x" "$T/keys/root"
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' "$NEW_CONF"
check "check fails when passwords are not refused" '! sw check >/dev/null'
sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' "$NEW_CONF"
check "nothing was changed by check" 'old_running && [ ! -e "$T/calls.changed" ] && ! grep -q stop "$T/calls"'
check "usage with no argument" '[ "$(sw 2>/dev/null | head -1)" != "" ]; sw >/dev/null 2>&1; [ $? = 2 ]'

# ---- backup
check "backup writes the tarball" 'sw backup >/dev/null && tar tzf "$BACKUP" | grep -q "usr/sbin/sshd"'
check "the backup is readable by the owner only (it holds private keys)" '[ "$(stat -c %a "$BACKUP")" = 600 ]'
check "a second backup does not overwrite" 'sw backup | grep -q "backup exists"'

# ---- trial, confirm
sw trial 4 > "$T/out" 2>&1; rc=$?
check "trial starts the new server on the port" '[ $rc = 0 ] && new_running && [ -e "$T/listen22" ]'
check "trial stopped the upstart job of the old one" 'grep -q "stop sshd" "$T/calls" && [ ! -e "$T/job" ]'
check "the safety timer runs" 'guard_running'
check "status says NEW and the timer" 'sw status | grep -q "NEW server" && sw status | grep -q "safety timer: running"'
sw confirm > "$T/out" 2>&1
check "confirm keeps the new server and stops the timer" 'new_running && ! guard_running && [ -e "$T/run/openssh-switch.ok" ]'
sleep 5
check "the new server is still there after the time ran out" 'new_running && [ ! -e "$T/job" ]'
check "status after confirm" 'sw status | grep -q "confirmed: yes"'

# ---- manual revert
sw revert > "$T/out" 2>&1
check "revert brings the old server back" 'old_running && ! new_running'
check "revert stopped the timer and left no ok file" '! guard_running && [ ! -e "$T/run/openssh-switch.ok" ]'

# ---- trial without a confirmation: the old server comes back by itself
sw trial 2 > "$T/out" 2>&1
check "second trial: the new server is up" 'new_running'
sleep 6
check "without confirm the old server came back by itself" 'old_running && ! new_running'
check "the revert was logged" 'grep -q "old server back" "$T/log"'

# ---- a new server that does not start: reverted at once, non-zero
touch "$T/bad_start"
sw trial 30 > "$T/out" 2>&1; rc=$?
check "a failing new server: trial reverts and fails" '[ $rc != 0 ] && old_running && grep -q "reverted" "$T/out"'
check "a failing trial leaves no timer" '! guard_running'
rm "$T/bad_start"

# ---- confirm without a trial
check "confirm without a trial fails" '! sw confirm >/dev/null 2>&1'
check "the old server is untouched by that" 'old_running'

# ---- restore
rm "$T/usr/sbin/sshd"
check "restore unpacks the backup" 'sw restore >/dev/null 2>&1; grep -q "old sshd binary" "$T/usr/sbin/sshd"'

# ---- trial refuses a bad port argument and a failing check
check "trial with a wrong time is refused" '! sw trial abc >/dev/null 2>&1'
touch "$T/bad_config"
check "trial does nothing when the check fails" 'n=$(grep -c "^stop" "$T/calls"); ! sw trial 5 >/dev/null 2>&1; [ "$(grep -c "^stop" "$T/calls")" = "$n" ]'
rm "$T/bad_config"

echo; echo "openssh-switch: $pass passed, $failed failed"
[ "$failed" = 0 ]
