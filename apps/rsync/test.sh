TEST_NAME=rsync
need_pkg rsync
ok in-path sh -c 'command -v rsync'
ok no-missing-libs sh -c '! ldd /opt/rsync/bin/rsync 2>&1 | grep -q "not found"'
t version 'rsync  version 3.5.2  protocol version 33' sh -c 'rsync --version | head -1'
rm -rf /tmp/rs-a /tmp/rs-b; mkdir -p /tmp/rs-a/sub; echo one > /tmp/rs-a/f1; echo two > /tmp/rs-a/sub/f2
ok copy-tree sh -c 'rsync -a /tmp/rs-a/ /tmp/rs-b/ && cmp /tmp/rs-a/sub/f2 /tmp/rs-b/sub/f2'
echo three > /tmp/rs-a/f3
ok only-differences sh -c 'rsync -a --stats /tmp/rs-a/ /tmp/rs-b/ | grep -q "Number of regular files transferred: 1"'
ok delete sh -c 'rm /tmp/rs-a/f1 && rsync -a --delete /tmp/rs-a/ /tmp/rs-b/ && test ! -e /tmp/rs-b/f1'
ok over-ssh-localhost sh -c 'rsync -a -e "ssh -o StrictHostKeyChecking=no -o BatchMode=yes" /tmp/rs-a/ root@127.0.0.1:/tmp/rs-b/ 2>/dev/null || echo skipped-no-ssh-key'
rm -rf /tmp/rs-a /tmp/rs-b
summary
