# irssi 1.4.5 for Maemo 5

IRC client in the terminal. First application on the static [GLib 2.66](../glib2/glib2.md); OpenSSL 3 (TLS 1.2/1.3) and ncursesw (UTF-8) are linked statically too, so only glibc and the standard libraries are needed.

```sh
make -C apps/irssi install     # build (when out of date), deb, scp, dpkg -i
make -C apps/irssi test        # tests on the phone
irssi                          # in a terminal (xterm)
/connect -tls irc.libera.chat 6697
/join #channel      /help      /quit
```

- Installs to `/opt/irssi`, link `/usr/bin/irssi`. The command is a small wrapper that sets `SSL_CERT_FILE=/opt/curl/etc/ssl/cacert.pem` (the CA bundle of the `curl` package, which the package depends on) and starts `irssi.bin`. The phone clock must be correct (certificate checks).
- Built without Perl, proxy, OTR and socks. Scripts in Perl do not work.
- Configuration goes to `~/.irssi/`. Run it as `user`, not root.
- [build.sh](build.sh): the link flags are rewritten after `configure` to full paths of the static libraries, because libtool moves `-Wl,-Bstatic` to the front and gold would find the system `libglib-2.0.so` (2.20), `libssl.so` (0.9.8) and `libncursesw.so.5` (not on the phone) in the sysroot first.

## Verified (2026-11-11)

- On the phone: 7 tests of `make test`; in `screen` as `user`: connection to `irc.libera.chat:6697` with TLS 1.3, also with `-tls_verify` (the CA bundle of the curl package works), MOTD and user mode shown, `/quit`.
- Not checked: long sessions, memory use, nick/channel work on the real keyboard (the Bluetooth keyboard is in [DOC/bluetooth-keyboard.md](../../DOC/bluetooth-keyboard.md)), several servers, DCC.
