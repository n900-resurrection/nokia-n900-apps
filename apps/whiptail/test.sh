TEST_NAME=whiptail
need_pkg whiptail
ok in-path sh -c 'command -v whiptail'
ok no-missing-libs sh -c '! ldd /opt/whiptail/bin/whiptail 2>&1 | grep -q "not found"'
contains version "whiptail" whiptail --version
contains help "--checklist" sh -c 'whiptail --help 2>&1'
summary
