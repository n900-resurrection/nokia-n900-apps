TEST_NAME=cointop
need_pkg cointop
ok in-path sh -c 'command -v cointop'
ok static-binary sh -c '! ldd /opt/cointop/bin/cointop 2>&1 | grep -q "not found"'
t version 'v1.6.10' sh -c 'cointop version'
ok runs-as-user sh -c 'su user -c "cointop version" | grep -q v1.6.10'
ok desktop-entry test -r /usr/share/applications/hildon/cointop.desktop
ok license test -r /opt/cointop/share/doc/cointop/LICENSE
ok help sh -c 'cointop help 2>&1 | grep -q "Available Commands"'
ok certificates test -s /opt/curl/etc/ssl/cacert.pem
summary
