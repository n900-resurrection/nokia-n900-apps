TEST_NAME=strace
need_pkg strace
ok in-path sh -c 'command -v strace'
ok no-missing-libs sh -c '! ldd /opt/strace/bin/strace 2>&1 | grep -q "not found"'
t version 'strace -- version 6.19' sh -c 'strace -V | head -1'
ok traces-open sh -c 'strace -o /tmp/strace-t.txt cat /etc/hostname >/dev/null 2>&1; grep -q "open(" /tmp/strace-t.txt'
ok traces-write sh -c 'strace -e trace=write -o /tmp/strace-t.txt echo hello >/dev/null 2>&1; grep -q "write(1, \"hello" /tmp/strace-t.txt'
ok follows-forks sh -c 'strace -f -o /tmp/strace-t.txt sh -c "cat /etc/hostname | wc -l" >/dev/null 2>&1; grep -q execve /tmp/strace-t.txt'
ok attach-pid sh -c 'sleep 20 & p=$!; sleep 1; timeout_s=3; (strace -p $p -o /tmp/strace-t.txt & s=$!; sleep 2; kill $p; sleep 1; kill $s 2>/dev/null); grep -q -E "nanosleep|restart_syscall|select" /tmp/strace-t.txt'
rm -f /tmp/strace-t.txt
summary
