TEST_NAME=ntp-sync
need_pkg ntp-sync
contains help "Usage: ntp-sync" ntp-sync -h
ok hook-installed test -x /etc/network/if-up.d/ntp-sync
ok config-installed test -r /etc/ntp-sync.conf
# -n only queries the servers (takes about 15 s), prints offsets and does not change the clock.
contains query-offset "offset" ntp-sync -n
t wrong-option-exit 2 sh -c 'ntp-sync -z >/dev/null 2>&1; echo $?'
summary
