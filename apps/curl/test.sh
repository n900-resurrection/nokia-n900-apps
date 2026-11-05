TEST_NAME=curl
need_pkg curl
contains version "curl 8." curl -V
contains protocols-mail "imaps" curl -V
contains tls-lib "mbedTLS" curl -V
t https-ok 'http=200 verify=0' curl -sS -o /dev/null -w 'http=%{http_code} verify=%{ssl_verify_result}\n' https://curl.se/
t tls13-github 'TLSv1.3' sh -c "curl -sS -v -o /dev/null https://github.com 2>&1 | grep -o 'TLSv1\.3' | head -1"
# Login-free checks: the server greeting arrives before authentication.
contains imaps-greeting "IMAP4rev1" sh -c "curl -sv -m 20 imaps://imap.centrum.cz/ 2>&1"
contains smtps-greeting "220 smtp.centrum.cz" sh -c "curl -sv -m 20 smtps://smtp.centrum.cz:465 2>&1"
ok bad-cert-rejected sh -c "! curl -sS -m 20 -o /dev/null https://expired.badssl.com/"
summary
