# WeeChat 4.10.4 for Maemo 5

Extensible chat client in the terminal (IRC; the plugins `irc`, `alias`, `buflist`, `charset`, `exec`, `fifo`, `fset`, `logger`, `trigger`, `typing`, `xfer`).
Built on the static [GnuTLS](../gnutls/gnutls.md) chain (TLS 1.2/1.3), libcurl with mbedTLS ([curl](../curl/curl.md)) and ncursesw (UTF-8), so only glibc, libz and the standard libraries are needed from the phone.

```sh
make -C apps/weechat install     # build (when out of date), deb, scp, dpkg -i
make -C apps/weechat test        # 7 tests on the phone
weechat                          # in a terminal (xterm)
/server add libera irc.libera.chat/6697 -tls
/connect libera      /join #channel      /help      /quit
```

- Installs to `/opt/weechat` (binary, plugins in `lib/weechat/plugins`), link `/usr/bin/weechat`. Configuration in `~/.weechat/`; run it as `user`.
- TLS verifies certificates against `/opt/curl/etc/ssl/cacert.pem` (compiled into GnuTLS; the package depends on `curl`). The clock of the phone must be correct (`ntp-sync`).
- **Not built:** scripting languages (Perl, Python, Ruby, Lua, Tcl, Guile, PHP), relay, script manager, spell checker, NLS, cJSON and zstd. WeeChat does not use GLib.
- [build.sh](build.sh): a CMake cross build (toolchain file written by the script). Static libraries are given at the end of the link line (`CMAKE_C_STANDARD_LIBRARIES`: GnuTLS needs libgcrypt and libgpg-error). libcurl was built against zlib 1.3.2 (`inflateReset2`), the phone has 1.2.3: the executable takes `inflate` from the static `libz.a` (`-u inflateReset2`); an empty `libatomic.a` satisfies `-latomic`.
  `htobe64` and friends come from [scripts/maemo-endian.h](../../scripts/maemo-endian.h) (glibc 2.5).

## Verified (2026-11-11)

- On the phone: 7 tests of `make test`; in `screen` as `user`: connection to `irc.libera.chat:6697` with TLS (certificate verified: `tls_verify` is on by default), MOTD and user mode shown, `/quit`.
- Not checked: long sessions, memory use (the binary is 5.4 MB), the look in `osso-xterm`, typing and channels on the real keyboard, `xfer` (DCC), logging, the speed of the TLS handshake on this CPU (no assembler code in the crypto libraries).
