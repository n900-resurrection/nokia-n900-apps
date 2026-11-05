TEST_NAME=cbonsai
need_pkg cbonsai
contains help "cbonsai is a beautifully random bonsai tree generator" cbonsai --help
ok link-in-path test -x /usr/bin/cbonsai
ok desktop-entry test -r /usr/share/applications/hildon/cbonsai.desktop
ok no-missing-libs sh -c "! ldd /opt/cbonsai/bin/cbonsai 2>&1 | grep -q \"not found\""
summary
