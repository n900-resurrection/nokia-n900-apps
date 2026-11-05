TEST_NAME=camel-lite-ssl3
need_pkg camel-lite-ssl3
t system-lib-is-ours /opt/camel-lite3/lib/libcamel-lite-1.2.so.0.0.0 readlink /usr/lib/libcamel-lite-1.2.so.0.0.0
t imap-provider-is-ours /opt/camel-lite3/providers/libcamelimap.so readlink /usr/lib/camel-lite-1.2/camel-providers/libcamelimap.so
ok originals-kept sh -c 'test -s /usr/lib/libcamel-lite-1.2.so.0.0.0.nss-orig && test -s /usr/lib/camel-lite-1.2/camel-providers/libcamelsmtp.so.nss-orig'
ok no-missing-libs sh -c '! ldd /usr/lib/libcamel-lite-1.2.so.0.0.0 2>&1 | grep -q "not found"'
ok other-providers-untouched sh -c 'test -f /usr/lib/camel-lite-1.2/camel-providers/libcamelas.so && ! test -L /usr/lib/camel-lite-1.2/camel-providers/libcamelas.so'
# Every user of the library finds all its symbols (a missing one made Modest crash at start in the first version).
t no-undefined-symbols 0 sh -c 'ldd -r /usr/lib/libtinymail-camel-1.0.so.0 /usr/lib/camel-lite-1.2/camel-providers/libcamelimap.so /usr/lib/camel-lite-1.2/camel-providers/libcamelsmtp.so /usr/lib/camel-lite-1.2/camel-providers/libcamelas.so 2>&1 | grep -c "undefined symbol"'
# Real TLS connections through the library (greeting of the server): needs the network and a correct clock.
if /opt/curl/bin/curl -s -o /dev/null --max-time 10 https://imap.centrum.cz:993 2>/dev/null; [ $? -ne 6 ] && [ $? -ne 28 ]; then
    mkdir -p /home/user/.camel-tlstest; chown user:users /home/user/.camel-tlstest
    contains tls-imap "BalaIMAP" su user -c '/opt/camel-lite3/bin/camel-tlstest imap.centrum.cz 993'
    contains tls-smtp "ESMTP" su user -c '/opt/camel-lite3/bin/camel-tlstest smtp.centrum.cz 465'
    rm -rf /home/user/.camel-tlstest
else
    skip tls-imap "no network"
    skip tls-smtp "no network"
fi
summary
