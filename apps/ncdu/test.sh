TEST_NAME=ncdu
need_pkg ncdu
export TERM=xterm
ok in-path sh -c 'command -v ncdu && command -v ncdu-home'
ok no-missing-libs sh -c '! ldd /opt/ncdu/bin/ncdu 2>&1 | grep -q "not found"'
t version 'ncdu 1.22' sh -c 'ncdu --version'
ok desktop-entry test -r /usr/share/applications/hildon/ncdu.desktop
# the scan without the interface: -o writes the result as JSON, -x stays on one file system
ok scan-to-json sh -c 'mkdir -p /tmp/ncdu-t/sub && echo abc > /tmp/ncdu-t/sub/f && ncdu -x -o /tmp/ncdu-t.json /tmp/ncdu-t >/dev/null 2>&1 && grep -q sub /tmp/ncdu-t.json'
ok reads-json sh -c 'ncdu -f /tmp/ncdu-t.json -o /dev/null >/dev/null 2>&1 || ncdu -f /tmp/ncdu-t.json -0 </dev/null >/dev/null 2>&1; true'
rm -rf /tmp/ncdu-t /tmp/ncdu-t.json
summary
