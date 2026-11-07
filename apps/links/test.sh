TEST_NAME=links
need_pkg links
ok in-path sh -c 'command -v links'
ok no-missing-libs sh -c '! ldd /opt/links/bin/links 2>&1 | grep -q "not found"'
t version 'Links 2.30' sh -c 'links -version'
ok desktop-entry test -r /usr/share/applications/hildon/links.desktop
ok ca-bundle test -s /opt/links/etc/cacert.pem
# dump a local page as text (no terminal needed)
ok dump-local sh -c 'printf "<html><body><h1>Hello N900</h1><p>text</p></body></html>" > /home/user/links-test.html && links -dump /home/user/links-test.html | grep -q "Hello N900"; r=$?; rm -f /home/user/links-test.html; exit $r'
# TLS 1.3 against a modern site with certificate verification (needs the network, otherwise skipped)
if curl -sI --max-time 10 https://example.org >/dev/null 2>&1; then
    ok https-tls13 sh -c 'links -dump https://example.org | grep -q "documentation examples"'
else
    skip https-tls13 "no network"
fi
summary
