# Profanity 0.19.0 for Maemo 5

XMPP (Jabber) client in the terminal. Third application on the static [GLib 2.66](../glib2/glib2.md); [libstrophe](../libstrophe/build.sh) with OpenSSL 3 (TLS 1.2/1.3), libcurl with mbedTLS ([curl](../curl/curl.md)), SQLite, readline and ncursesw (UTF-8) are linked statically too.

```sh
make -C apps/profanity install     # build (when out of date), deb, scp, dpkg -i
make -C apps/profanity test        # 7 tests on the phone
profanity                          # in a terminal (xterm)
/connect myjid@domain.org          # asks for the password
/msg friend@domain.org hello       /join room@conference.domain.org       /help       /quit
```

- Installs to `/opt/profanity` (themes in `share/profanity/themes`), link `/usr/bin/profanity`. The command is a wrapper that sets `SSL_CERT_FILE=/opt/curl/etc/ssl/cacert.pem` (the CA bundle of the `curl` package, a dependency) and starts `profanity.bin`. The clock of the phone must be correct. Configuration and the chat history database are in `~/.local/share/profanity` and `~/.config/profanity`; run it as `user`.
- **Not built:** OMEMO (needs libsignal-protocol-c or libomemo-c), OTR, PGP, Python and C plugins, desktop notifications, spell checker, icons and clipboard. For end-to-end encryption OMEMO would be the one to add (libomemo-c uses CMake and can use libgcrypt or OpenSSL).
- [build.sh](build.sh) (meson cross build, `prefer_static`): `libcurl.pc` of the curl build is copied with the real paths, SQLite has no `.pc` file (written by the script). libstrophe defines `tls_free` and 21 other `tls_*` functions that clash with libssl.a in a static link: [apps/libstrophe/build.sh](../libstrophe/build.sh) renames them inside the archive (`objcopy --redefine-syms`) and removes `Requires.private` (no `expat.pc` or `openssl.pc` for the target).
- The binary is 10 MB (static OpenSSL, libcurl with mbedTLS, SQLite, GLib with GIO).

## Verified (2026-11-11)

- On the phone: 7 tests; the interface starts in `screen` as `user` with `TERM=xterm` (welcome text, `[offline]` status bar), `/quit` works.
- **Not checked:** a connection to a server (needs an XMPP account: a login with a fake account on a public server was not tried on purpose), TLS certificate verification against the CA bundle, message exchange, the history database, the look in `osso-xterm`, memory use.
