TEST_NAME=cmatrix
need_pkg cmatrix
contains version "CMatrix version 2.0" cmatrix -V
ok link-in-path test -x /usr/bin/cmatrix
ok desktop-entry test -r /usr/share/applications/hildon/cmatrix.desktop
ok no-missing-libs sh -c "! ldd /opt/cmatrix/bin/cmatrix 2>&1 | grep -q \"not found\""
summary
