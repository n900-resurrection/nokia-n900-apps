TEST_NAME=msmtp
need_pkg msmtp
contains version "msmtp version 1.8" msmtp --version
contains tls-openssl "TLS/SSL library: OpenSSL" msmtp --version
ok example-installed test -r /opt/msmtp/share/doc/msmtp/msmtprc.centrum.example
# --serverinfo connects, checks the certificate and prints the capabilities; no login, no mail.
contains centrum-capabilities "AUTH" msmtp --serverinfo --host=smtp.centrum.cz --port=465 --tls=on --tls-starttls=off --tls-trust-file=/opt/curl/etc/ssl/cacert.pem
contains centrum-cert "CN=*.centrum.cz" msmtp --serverinfo --host=smtp.centrum.cz --port=465 --tls=on --tls-starttls=off --tls-trust-file=/opt/curl/etc/ssl/cacert.pem
ok bad-trust-file-rejected sh -c "! msmtp --serverinfo --host=smtp.centrum.cz --port=465 --tls=on --tls-starttls=off --tls-trust-file=/dev/null"
summary
