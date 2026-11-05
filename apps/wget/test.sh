TEST_NAME=wget
need_pkg wget
contains version "GNU Wget 1.25" wget --version
contains openssl "+ssl/openssl" wget --version
t https-github 'HTTP/1.1 200 OK' sh -c "wget -S -O /dev/null https://github.com 2>&1 | grep -o 'HTTP/1.1 200 OK' | head -1"
contains http-plain "Example Domain" wget -q -O - http://example.com
ok bad-cert-rejected sh -c "! wget -q -O /dev/null https://expired.badssl.com/"
t link-in-path /usr/bin/wget sh -c 'command -v wget'
summary
