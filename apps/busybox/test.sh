TEST_NAME=busybox37
need_pkg busybox37
export PATH=/opt/busybox37/bin:$PATH
tmpdir
contains version "BusyBox v1.37" busybox
t system-busybox-untouched "BusyBox v1.23" sh -c '/bin/busybox | head -1 | cut -c1-13'
t path-order /opt/busybox37/bin/awk sh -c 'command -v awk'
t awk-pow 1024 awk 'BEGIN{print 2^10}'
t sed-i X sh -c 'echo a > f; sed -i s/a/X/ f; cat f'
t sort-uniq "1 a
2 b" sh -c 'printf "b\na\nb\n" | sort | uniq -c | awk "{print \$1, \$2}" | sort -k2'
t grep-o "12 34" sh -c 'echo "x12y34" | grep -oE "[0-9]+" | tr "\n" " " | sed "s/ $//"'
t find-xargs 3 sh -c 'touch a1 a2 a3; find . -name "a?" | xargs ls | wc -l'
t tar-gz-roundtrip same sh -c 'mkdir -p src; echo data > src/x; tar czf s.tgz src; rm -r src; tar xzf s.tgz; [ "$(cat src/x)" = data ] && echo same'
t sha256 "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824  -" sh -c 'printf hello | sha256sum'
t base64 aGVsbG8= sh -c 'printf hello | base64'
t touch-date "2020-01-02" sh -c 'touch -d "2020-01-02 03:04:05" tt; date -r tt +%F'
t stat-size 6 sh -c 'echo hello > h; stat -c %s h'
t timeout-kills 143 sh -c 'timeout 1 sleep 5 2>/dev/null; echo $?'
t ash-arith 42 ash -c 'echo $((6*7))'
t wget-http ok sh -c 'wget -q -O - http://example.com | grep -q "Example Domain" && echo ok'
# Interplay with bash5 (only when it is installed)
if command -v bash5 >/dev/null; then
    t bash5-uses-bb-pipe 3 bash5 -c 'seq 1 3 | tail -n 1'
    t bash5-procsub same bash5 -c 'diff <(printf "a\nb\n") <(printf "a\nb\n") >/dev/null && echo same'
    t bb-find-exec-bash5 ok sh -c 'touch q1; find . -name q1 -exec bash5 -c "[[ \$1 == ./q1 ]] && echo ok" _ {} \;'
    t bash5-command-v /opt/busybox37/bin/awk bash5 -c 'command -v awk'
else
    skip bash5-interplay "bash5 is not installed"
fi
summary
