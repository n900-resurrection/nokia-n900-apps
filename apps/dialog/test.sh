TEST_NAME=dialog
need_pkg dialog
ok in-path sh -c 'command -v dialog'
ok no-missing-libs sh -c '! ldd /opt/dialog/bin/dialog 2>&1 | grep -q "not found"'
contains version "Version: 1.3" dialog --version
# dialog needs a terminal: run it in a pseudo terminal where possible (script from busybox), otherwise only check the exit status of --print-maxsize
ok print-maxsize sh -c 'TERM=xterm dialog --print-maxsize 2>&1 | grep -q MaxSize'
summary
