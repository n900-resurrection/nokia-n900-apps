TEST_NAME=smb
need_pkg smb
contains usage "Usage: smb" smb
contains usage-bad-version "Usage: smb" smb -v 1 ls smb://x/y
contains url-needs-share "needs host and share" smb ls smb://127.0.0.1/
contains no-scheme "does not start with" smb ls //host/share
contains refused-port "connect" smb ls smb://127.0.0.1:1/share/
t binary-static 0 sh -c 'ldd /opt/smb/bin/smb 2>&1 | grep -c libsmb2; true'
summary
