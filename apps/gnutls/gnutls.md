# GnuTLS 3.8 (static build dependency)

GnuTLS with the libraries it needs, built as **static, position independent** libraries (not a package, like [glib2](../glib2/glib2.md) and [openssl](../openssl/build.sh)):
GMP 6.3.0, Nettle 3.10.1, libtasn1 4.20.0, libgpg-error 1.51, libgcrypt 1.11.0 and GnuTLS 3.8.13, all in `build/deps/gnutls-3.8.13/{include,lib}`. `make -C apps/gnutls build` (about 20 minutes).
First user: [WeeChat](../weechat/weechat.md) (GnuTLS is the only TLS library it supports).

- Built with `-fPIC` because WeeChat links them into its plugin modules (`irc.so`, `xfer.so`); without it gold stops with `unsupported dynamic reloc R_ARM_MOVW_ABS_NC`.
- No assembler code (GMP, Nettle, libgcrypt, GnuTLS) and no p11-kit, no command line tools: the build is the same as every other one with the sysroot compiler, but slower at run time.
- The default trust store of GnuTLS is compiled in as `/opt/curl/etc/ssl/cacert.pem` (the CA bundle of the `curl` package), so programs using it need that package and a correct clock.
- `ONLY=gnutls-3.8.13 make -C apps/gnutls build` (variable passed into the Workshop by `build.sh`, see its header) rebuilds only one library into the existing prefix. Without `ONLY` the prefix is wiped first.
- `make` for an application that lists `gnutls` in `DEPS` rebuilds everything when `build.sh` is newer than `build/stamps/gnutls-*.built`; touch the stamp after a hand edit of the script.
- `gnutls.pc` asks for `-latomic`, which the sysroot lacks: the WeeChat build supplies an empty `libatomic.a`.
