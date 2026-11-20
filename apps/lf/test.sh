TEST_NAME=lf
need_pkg lf
ok in-path sh -c 'command -v lf'
ok static-binary sh -c '! ldd /opt/lf/bin/lf 2>&1 | grep -q "not found"'
t version 'r41' sh -c 'lf -version'
ok runs-as-user sh -c 'su user -c "lf -version" | grep -q r41'
ok desktop-entry test -r /usr/share/applications/hildon/lf.desktop
ok license test -r /opt/lf/share/doc/lf/LICENSE
ok manual test -r /opt/lf/share/man/man1/lf.1.gz
# a non-interactive command: lf -remote needs a server; instead the documentation and the default configuration are checked
ok example-config test -s /opt/lf/share/doc/lf/lfrc.example
summary
