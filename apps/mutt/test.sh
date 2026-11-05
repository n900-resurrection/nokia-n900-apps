TEST_NAME=mutt
need_pkg mutt
contains version "Mutt 2.4" mutt -v
contains imap "+USE_IMAP" mutt -v
contains smtp "+USE_SMTP" mutt -v
contains openssl "+USE_SSL_OPENSSL" mutt -v
contains no-gnutls "-USE_SSL_GNUTLS" mutt -v
ok example-installed test -r /opt/mutt/share/doc/mutt/muttrc.centrum.example
# Configuration parsing: the example must load without errors (-Q only queries a variable, no UI, no network).
t example-parses 'sendmail="/usr/bin/msmtp -a centrum"' mutt -F /opt/mutt/share/doc/mutt/muttrc.centrum.example -Q sendmail
t default-charset 'charset="utf-8"' mutt -F /opt/mutt/share/doc/mutt/muttrc.centrum.example -Q charset
t system-certs 'ssl_usesystemcerts is set' sh -c 'mutt -F /opt/mutt/share/doc/mutt/muttrc.centrum.example -D | grep ssl_usesystemcerts'
ok ca-link-resolves test -s /opt/openssl/etc/ssl/cert.pem
ok ca-file-exists test -s /opt/curl/etc/ssl/cacert.pem
# UTF-8 needs the wide-character curses: no dynamic libncursesw is needed.
ok no-missing-libs sh -c '! ldd /opt/mutt/bin/mutt 2>&1 | grep -q "not found"'
# The server accepts our TLS before any login (greeting only, no credentials).
contains imaps-greeting "IMAP4rev1" sh -c "curl -sv -m 20 imaps://imap.centrum.cz/ 2>&1"
ok msmtp-installed test -x /usr/bin/msmtp
summary
