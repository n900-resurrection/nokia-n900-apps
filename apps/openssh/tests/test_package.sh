#!/bin/bash
# Tests of the two kinds of the package (parallel 1maemo5, replacing 1maemo6) from the built .deb files: the control fields, the files and links, the upstart job,
# the init script and the logic of postinst with fake commands in a temporary tree (nothing is installed, nothing real is started):  bash tests/test_package.sh
HERE=$(cd "$(dirname "$0")" && pwd)
DEB=${DEB_DIR:-$HERE/../../../build/deb}
PAR=$DEB/openssh_10.6p2-1maemo5_armel.deb
REP=$DEB/openssh_10.6p2-1maemo${REP_REV:-7}_armel.deb
pass=0; failed=0
T=$(mktemp -d); trap 'pkill -f "$T" 2>/dev/null; rm -rf "$T"' EXIT
ok()  { pass=$((pass + 1)); echo "ok    $1"; }
bad() { failed=$((failed + 1)); echo "FAIL  $1"; [ -n "$2" ] && echo "      $2"; }
check() { if eval "$2"; then ok "$1"; else bad "$1" "$2"; fi; }
[ -f "$PAR" ] && [ -f "$REP" ] || { echo "build both first: make -C apps/openssh deb; make -C apps/openssh deb REV=1maemo6"; exit 1; }

mkdir -p "$T/par" "$T/rep"
dpkg-deb -x "$PAR" "$T/par"; dpkg-deb -e "$PAR" "$T/par/DEBIAN"
dpkg-deb -x "$REP" "$T/rep"; dpkg-deb -e "$REP" "$T/rep/DEBIAN"
ctl() { dpkg-deb -f "$1" "$2"; }

echo "== parallel kind (1maemo5)"
check "version has the epoch"                       '[ "$(ctl $PAR Version)" = "1:10.6p2-1maemo5" ]'
check "no Provides, Conflicts or Replaces"          '[ -z "$(ctl $PAR Provides)$(ctl $PAR Conflicts)$(ctl $PAR Replaces)" ]'
check "it does not touch the system OpenSSH"        '[ ! -e "$T/par/etc/event.d/sshd" ] && [ ! -e "$T/par/etc/init.d/ssh" ] && [ ! -e "$T/par/usr/bin/ssh" ] && [ ! -e "$T/par/usr/sbin/sshd" ]'
check "the -modern client names"                    'for c in ssh scp sftp ssh-keygen; do [ -L "$T/par/usr/bin/$c-modern" ] || exit 1; done'
check "openssh-switch is in the package and linked" '[ -x "$T/par/opt/openssh/sbin/openssh-switch" ] && [ "$(readlink "$T/par/usr/sbin/openssh-switch")" = ../../opt/openssh/sbin/openssh-switch ]'
check "the default configuration: port 2222, keys only" 'grep -q "^Port 2222" "$T/par/opt/openssh/etc/sshd_config.default" && grep -q "^PasswordAuthentication no" "$T/par/opt/openssh/etc/sshd_config.default" && grep -q "^PidFile /var/run/sshd-modern.pid" "$T/par/opt/openssh/etc/sshd_config.default"'
check "root only with a key, only the named accounts" 'grep -q "^PermitRootLogin prohibit-password" "$T/par/opt/openssh/etc/sshd_config.default" && grep -q "^AllowUsers user root" "$T/par/opt/openssh/etc/sshd_config.default"'
check "no sshd_config in the package itself"        '[ ! -e "$T/par/opt/openssh/etc/sshd_config" ]'
check "no host keys in the package"                 '! ls "$T/par"/opt/openssh/etc/ssh_host_* >/dev/null 2>&1'
for s in postinst prerm postrm; do check "parallel $s is valid sh" 'sh -n "$T/par/DEBIAN/$s"'; done

echo "== replacing kind (1maemo6)"
check "version has the epoch"                       '[ "$(ctl $REP Version)" = "1:10.6p2-1maemo${REP_REV:-7}" ]'
for f in Provides Conflicts Replaces; do check "$f the three old packages" '[ "$(ctl $REP '$f')" = "openssh-client, openssh-server, openssh-common" ]'; done
check "it is not a dependency of itself"            '! ctl $REP Depends | grep -q openssh'
check "the clients are links into /opt/openssh"     'for c in ssh scp sftp ssh-keygen ssh-add ssh-agent; do [ "$(readlink "$T/rep/usr/bin/$c")" = "../../opt/openssh/bin/$c" ] || exit 1; done'
check "slogin is ssh"                               '[ "$(readlink "$T/rep/usr/bin/slogin")" = ssh ]'
check "every link points at a file that exists in the package" 'cd "$T/rep" && for l in usr/bin/ssh usr/bin/scp usr/bin/sftp usr/bin/ssh-keygen usr/bin/ssh-add usr/bin/ssh-agent usr/sbin/sshd usr/lib/openssh/sftp-server usr/lib/sftp-server; do [ -e "$(dirname $l)/$(readlink $l)" ] || { echo "dangling $l"; exit 1; }; done'
check "sshd is a link to the new one"               '[ "$(readlink "$T/rep/usr/sbin/sshd")" = ../../opt/openssh/sbin/sshd ]'
check "the upstart job runs the new sshd in the foreground, respawning" 'grep -q "^exec /opt/openssh/sbin/sshd -D" "$T/rep/etc/event.d/sshd" && grep -q "^respawn" "$T/rep/etc/event.d/sshd" && grep -q "^start on stopped rcS" "$T/rep/etc/event.d/sshd"'
check "the job waits for /opt to be mounted (it is mounted late at boot)" 'grep -q "while \[ ! -x /opt/openssh/sbin/sshd \]" "$T/rep/etc/event.d/sshd" && grep -q "sshd -t || exit 1" "$T/rep/etc/event.d/sshd"'
# the pre-start script on its own, with /opt in a temporary tree where the server appears after two seconds (the way /opt appears at boot)
sed -n '/^pre-start script/,/^end script/p' "$T/rep/etc/event.d/sshd" | sed '1d;$d' | sed -e "s|/opt/openssh|$T/mnt/opt/openssh|g" -e "s|/var/run/sshd|$T/mnt/run/sshd|g" > "$T/prestart.sh"
mkdir -p "$T/mnt/run" "$T/mnt/opt/openssh/sbin"
( sleep 2; printf '#!/bin/sh\nexit 0\n' > "$T/mnt/opt/openssh/sbin/sshd"; chmod 755 "$T/mnt/opt/openssh/sbin/sshd" ) &
s0=$(date +%s); sh "$T/prestart.sh"; rc=$?; waited=$(( $(date +%s) - s0 ))
check "pre-start waits until the server appears, then succeeds" '[ $rc = 0 ] && [ $waited -ge 2 ] && [ $waited -lt 20 ] && [ -d "$T/mnt/run/sshd" ]'
printf '#!/bin/sh\nexit 1\n' > "$T/mnt/opt/openssh/sbin/sshd"
sh "$T/prestart.sh"; rc2=$?
check "pre-start fails when sshd -t fails" '[ $rc2 != 0 ]'
check "the job refuses to start with a broken configuration" 'grep -q "sshd -t || exit 1" "$T/rep/etc/event.d/sshd"'
check "the default configuration: port 22, the pid file gothi looks at" 'grep -q "^Port 22$" "$T/rep/opt/openssh/etc/sshd_config.default" && grep -q "^PidFile /var/run/sshd.pid" "$T/rep/opt/openssh/etc/sshd_config.default" && grep -q "^PasswordAuthentication no" "$T/rep/opt/openssh/etc/sshd_config.default"'
check "init script, valid sh and executable"        'sh -n "$T/rep/etc/init.d/ssh" && [ -x "$T/rep/etc/init.d/ssh" ]'
check "init script gives the old interface"         'for a in start stop restart reload status; do grep -q "^  .*$a" "$T/rep/etc/init.d/ssh" || exit 1; done'
check "the packages ship the switch script too"     '[ -x "$T/rep/opt/openssh/sbin/openssh-switch" ]'
for s in postinst prerm postrm; do check "replacing $s is valid sh" 'sh -n "$T/rep/DEBIAN/$s"'; done

echo "== init script with fake start and stop"
mkdir -p "$T/fb"
for c in start stop status; do printf '#!/bin/sh\necho "%s $*" >> "%s/init.calls"\nexit 0\n' "$c" "$T" > "$T/fb/$c"; done
printf '#!/bin/sh\nexit 0\n' > "$T/fb/sshd-ok"; chmod 755 "$T"/fb/*
sed "s|/opt/openssh/sbin/sshd|$T/fb/sshd-ok|g" "$T/rep/etc/init.d/ssh" > "$T/initssh"; chmod 755 "$T/initssh"
(PATH="$T/fb:$PATH"; "$T/initssh" start >/dev/null; "$T/initssh" stop >/dev/null; "$T/initssh" restart >/dev/null)
check "start and stop go through the upstart job"   'grep -q "^start sshd" "$T/init.calls" && grep -q "^stop sshd" "$T/init.calls"'
check "restart tests the configuration, then stops and starts" '[ "$(grep -c "^stop sshd" "$T/init.calls")" = 2 ] && [ "$(grep -c "^start sshd" "$T/init.calls")" = 2 ]'
check "an unknown action is an error"               '! "$T/initssh" frobnicate >/dev/null 2>&1'

echo "== postinst with fake commands in a temporary tree"
run_postinst() {         # run_postinst <par|rep> <dir>: the script with its paths moved into <dir>
    d=$2; rm -rf "$d"; mkdir -p "$d/opt/openssh/etc" "$d/opt/openssh/var/empty" "$d/opt/openssh/bin" "$d/opt/openssh/sbin" "$d/run" "$d/etc" "$d/bin"
    cp "$T/$1/opt/openssh/etc/sshd_config.default" "$d/opt/openssh/etc/"
    : > "$d/etc/passwd"
    printf '#!/bin/sh\nfor a in "$@"; do last=$a; done\necho key > "$last"\n' > "$d/opt/openssh/bin/ssh-keygen"
    printf '#!/bin/sh\nfor a in "$@"; do [ "$a" = -t ] && { [ -e "%s/bad_config" ] && exit 1; exit 0; }; done\nexit 0\n' "$d" > "$d/opt/openssh/sbin/sshd"
    for c in start stop adduser chown; do printf '#!/bin/sh\necho "%s $*" >> "%s/calls"\nexit 0\n' "$c" "$d" > "$d/bin/$c"; done
    chmod 755 "$d"/opt/openssh/bin/* "$d"/opt/openssh/sbin/* "$d"/bin/*
    sed -e "s|/opt/openssh|$d/opt/openssh|g" -e "s|/var/run/sshd.pid|$d/run/sshd.pid|g" -e "s|/etc/passwd|$d/etc/passwd|g" -e "s|/proc/\\\$p/cmdline|/proc/\$p/cmdline|" "$T/$1/DEBIAN/postinst" > "$d/postinst"
    [ -n "$3" ] && eval "$3"
    (cd "$d" && PATH="$d/bin:$PATH" sh "$d/postinst" > "$d/out" 2> "$d/err"); echo $? > "$d/rc"
}
D=$T/p1; run_postinst par $D
check "parallel: the configuration is created from the default (port 2222)" 'grep -q "^Port 2222" "$D/opt/openssh/etc/sshd_config" && [ "$(cat $D/rc)" = 0 ]'
check "parallel: host keys are made"                '[ -s "$D/opt/openssh/etc/ssh_host_ed25519_key" ] && [ -s "$D/opt/openssh/etc/ssh_host_rsa_key" ]'
check "parallel: nothing is started or stopped"     '! grep -qE "^(start|stop)" "$D/calls"'
check "parallel: it says the system server keeps running" 'grep -q "keeps running on port 22" "$D/out"'
check "the user sshd is created when missing"       'grep -q "^adduser" "$D/calls"'
D=$T/p2; run_postinst par $D 'printf "Port 9999\n" > "$d/opt/openssh/etc/sshd_config"'
check "parallel: an existing configuration is left alone" '[ "$(cat $D/opt/openssh/etc/sshd_config)" = "Port 9999" ]'
D=$T/p3; run_postinst rep $D 'cp "$T/par/opt/openssh/etc/sshd_config.default" "$d/opt/openssh/etc/sshd_config"'
check "replacing: the parallel configuration becomes port 22, the old one is kept" 'grep -q "^Port 22$" "$D/opt/openssh/etc/sshd_config" && grep -q "^Port 2222" "$D/opt/openssh/etc/sshd_config.parallel"'
check "replacing: the upstart job is restarted"     'grep -q "^stop sshd" "$D/calls" && grep -q "^start sshd" "$D/calls" && [ "$(cat $D/rc)" = 0 ]'
check "replacing: it says the job runs on port 22"  'grep -q "upstart job sshd on port 22" "$D/out"'
D=$T/p4; run_postinst rep $D 'printf "Port 2200\nPasswordAuthentication no\n" > "$d/opt/openssh/etc/sshd_config"'
check "replacing: a configuration of the owner is kept" '[ "$(head -1 $D/opt/openssh/etc/sshd_config)" = "Port 2200" ] && [ ! -e "$D/opt/openssh/etc/sshd_config.parallel" ]'
D=$T/p5; run_postinst rep $D 'touch "$d/bad_config"'
check "replacing: a broken configuration is NOT started, with a warning" '! grep -qE "^(start|stop)" "$D/calls" && grep -q "WARNING" "$D/err" && [ "$(cat $D/rc)" = 0 ]'
D=$T/p6; run_postinst rep $D 'setsid sh -c "echo \$\$ > $d/run/sshd.pid; while :; do sleep 1; done # $d/opt/openssh/sbin/sshd" >/dev/null 2>&1 </dev/null & sleep 1'
sleep 3
check "replacing: the server of the trial is stopped before the job starts" '! kill -0 "$(cat $D/run/sshd.pid)" 2>/dev/null && grep -q "^start sshd" "$D/calls"'

echo; echo "openssh package: $pass passed, $failed failed"
[ "$failed" = 0 ]
