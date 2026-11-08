# MicroB (the stock browser of Maemo 5): state and plan (2026-11-08)

## State on the phone
- engine: Gecko 1.9.2 (Firefox 3.6 era), package `microb-engine` 20100401-1.9.2-5.2+0m5, libraries in `/usr/lib/microb-engine` (NSS 3.12.6.2, NSPR 4.8.3);
- TLS: only SSL 3.0 and TLS 1.0, so Google, Facebook, Seznam and most of the web fail ("upgrade to TLS 1.2", SSL error);
- root certificates: `libnssckbi.so` of MicroB is a symlink to `libmaemosec_certman` (Nokia certificate manager, domains `common-ca` from 2010, read only, and
  private domains in `~/.maemosec-certs`). Solved by the package `ca-certs-n900` (adds the current Mozilla roots into the private domain `ssl-ca`); verified with
  `https://tls-v1-0.badssl.com:1010/`.

## Sources (found 2026-11-08)
The repository `repository.maemo.org` is not reachable, but the Internet Archive has the pool directory (snapshot 2020-09-28) with the **exact source package of the
phone**. Downloaded and checked (MD5 as in the `.dsc`) into `build/downloads/microb-engine/`, extracted into `build/src/microb-engine/` (391 MB, not in git):

```
B=http://web.archive.org/web/2020id_/http://repository.maemo.org/pool/maemo5.0/free/m/microb-engine
$B/microb-engine_20100401-1.9.2-5.2+0m5.dsc
$B/microb-engine_20100401-1.9.2-5.2+0m5.diff.gz     (1.5 MB: debian/ directory, 129 patches, build configuration)
$B/microb-engine_20100401-1.9.2.orig.tar.gz         (58 MB: the whole Mozilla 1.9.2 tree with security/nss, nsprpub, security/manager)
```
(Also listed there: the older 20090612 and 20091230-1.9.2 versions.) The `.dsc` builds libnspr4, libnss3, libnss3-certs, microb-xulrunner, microb-engine, microb-full... Maintainer
Oleg Romashin (Nokia). The 129 Debian patches touch the engine and UI (certificate exception dialog, certificate view) but not the NSS library itself.

## Idea: newer NSS under the unchanged engine (not tried yet)
PSM (`security/manager/ssl/src/nsNSSComponent.cpp`) sets protocols only with the old option calls `SSL_OptionSetDefault(SSL_ENABLE_SSL3/SSL_ENABLE_TLS, ...)`,
no version ranges. In newer NSS (3.14+) these options only enable or disable a protocol inside the library's version range, whose default maximum is TLS 1.2 (3.15.1+), so the
engine could negotiate TLS 1.2 **without changing Gecko**, only by replacing `libssl3`, `libnss3`, `libnssutil3`, `libsoftokn3`, `libfreebl3` (and NSPR if needed) in
`/usr/lib/microb-engine`. To verify first: the behaviour of `SSL_ENABLE_TLS` in the chosen NSS version (sslsock.c), whether newer NSS still has every API symbol that
libxul (the engine) imports (`nm -D` of the engine libraries against the new libnss3), the PKCS#11 module `libnssckbi.so` (certman) and the `cert8.db` format (NSS 3.x
before 3.35 still uses the old dbm format by default, which fits), build with the project cross compiler (static or in `/opt`, glibc 2.5, armel), RAM and size.
Safer layout: a separate directory `/opt/microb-nss/lib` and a wrapper that sets `LD_LIBRARY_PATH` only for MicroB, so that the stock libraries stay untouched
(and the system can be restored by removing the package).

Candidates: NSS 3.15.x to 3.28 (TLS 1.2 with the old build system and the dbm database; later versions need gyp/ninja and `sql:` databases). Note that modern servers also
want SNI (supported by NSS 3.12), ECDHE and AES-GCM (the old NSS lacks GCM before 3.15.2), and TLS 1.3 only servers are out of reach for this approach.

## Prototype analysis of NSS 3.28.6 (2026-11-08, nothing built yet)
The source is archived in the sub repository `apps/microb-engine` (a "fork" of the Debian source package, so it does not have to be hunted again). NSS 3.28.6 with
NSPR 4.16 (`nss-3.28.6-with-nspr-4.16.tar.gz`, SHA-256 `311ca1a8...78975d`, from archive.mozilla.org) is in `build/downloads/nss/`; 3.15.5 was looked at too.

**1. Behaviour of `SSL_ENABLE_TLS`** (`lib/ssl/sslsock.c`): the default version range of a stream socket in 3.28.6 is **TLS 1.0 to TLS 1.2**, and
`ssl_EnableTLS(on)` only *widens* the range to include TLS 1.0 (`PR_MIN`/`PR_MAX`), never lowers the maximum. PSM sets only `SSL_ENABLE_SSL3/TLS`, so MicroB
would negotiate TLS 1.2 with the unchanged engine. In 3.15.5 the default range ends at TLS 1.0, so it is not enough. (SSL 2 is gone in 3.28, PSM only
switches it off; SSL 3 is off by default, which is fine.)

**2. Symbols** (`scripts/microb-nss-abi-check.sh`): the engine libraries (`libxul`, `libmozjs`, `libxpcom`, `libsmime3`, ...) import 871 symbols from the stock NSS/NSPR
libraries; **all 871 are exported by NSS 3.28.6 + NSPR 4.16+** (the data symbols such as `CERT_NameTemplate` are listed with `;;` in the `.def` files and are exported on Unix), and
**all 29 ELF version nodes** (`NSS_3.2` ... `NSS_3.12.6`, `NSSUTIL_3.12.x`) are defined. Nothing is lost by the replacement. NSPR must be replaced too (NSS 3.28 needs >= 4.13).

**3. Cipher suites: a problem to solve.** PSM (`nsNSSComponent.cpp`, around line 1679) first **disables every cipher suite** of the library
(`SSL_CipherPrefSetDefault(id, PR_FALSE)` for all `SSL_ImplementedCiphers`) and then enables only its own compile-time table: AES/3DES/RC4 with SHA-1 (CBC),
ECDHE and DHE included. The suites of TLS 1.2 (AES-GCM, SHA-256 MACs, ChaCha20) would stay off, so sites that dropped the CBC suites still fail even with TLS 1.2.
Fix without rebuilding the engine: a small patch in our NSS (`ssl3_CipherPrefSetDefault` ignores "off" for the modern suites, or the library enables them after
the application's setup). To be done and tested.

**4. Other checks.** The cookie/cert databases: NSS 3.28 still opens the legacy `cert8.db`/`key3.db` (dbm) by default (the `sql:` default came with 3.35); the `libnssckbi.so`
(certman) module is a PKCS#11 module and does not depend on the NSS version; `libsoftokn3` needs `libnssdbm3` and `libfreebl3`. No `getauxval`, `getrandom`, `eventfd`, `epoll`
or `accept4` in NSPR/freebl, so glibc 2.5 and kernel 2.6.28 should be fine.

**Next steps:** (a) cross-build NSPR 4.16 and NSS 3.28.6 for armel (NSPR `configure --target`, NSS `make` with `CROSS_COMPILE`, `NATIVE_CC`, `BUILD_OPT=1`,
`NSS_DISABLE_GTESTS=1`; needs a native build of `nsinstall`, zlib), (b) the cipher patch, (c) a package `microb-nss` with the libraries in `/opt/microb-nss/lib` and a wrapper
(`LD_LIBRARY_PATH`) for MicroB, (d) tests: `tstclnt`/`selfserv` of NSS under qemu, then MicroB on `https://tls-v1-2.badssl.com:1012/` and real sites, and a path back (remove the package).

## Build result (2026-11-08): `apps/microb-nss`
NSPR 4.16 and NSS 3.28.6 are cross-built for armel (`make -C apps/microb-nss build`, about 2 minutes; the package is 1.3 MB) with three patches (`apps/microb-nss/patches`):
the cipher suites of TLS 1.2 stay enabled although PSM switches every suite off, SSL 3.0 cannot be enabled, and the SQLite of NSS is renamed to `libnsssqlite3.so` (MicroB has its own
`libsqlite3.so` in the same directory). `libfreebl3.so` is only a small loader of `libfreeblpriv3.so`, which is shipped too.

Checked on the **built** libraries: all 871 symbols that the engine imports exist, and all ELF version nodes it needs (`NSS_3.2` ... `NSS_3.12.6`, `NSSUTIL_3.12.x`) are defined.
`psm-sim` (`apps/microb-nss/psm-sim.c`) sets NSS up as PSM does (SSL 3 and TLS on, all suites off, then the old CBC list on) and was run under qemu-user against real servers:
tls-v1-2.badssl.com (TLS 1.2), www.google.com, www.facebook.com and example.org (TLS 1.2, `TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256`), www.seznam.cz (TLS 1.2, `TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256`):
**the sites that fail in the stock MicroB negotiate TLS 1.2, and the patch makes the GCM suites work although PSM does not enable them.**

**How it gets into MicroB.** The engine runs in the daemon `browserd` (started by `/etc/init.d/tablet-browser-daemon.init`) and finds its libraries through `/etc/ld.so.conf`
(`/usr/lib/microb-engine`). The package puts links to `/opt/microb-nss/lib` into that directory and moves the stock files to `/usr/lib/microb-engine-orig` with `dpkg-divert`; removing the
package puts them back. Its `postinst` first checks that the new libraries load. Nothing is restarted by the package.

**Installed on the phone (2026-11-08, 13 tests pass, `psm-sim` handshakes take at most 1 s on the phone).** The first install (revision 1maemo1) failed half way and left the package
half-configured: the old `dpkg-divert` has no `--listpackage` and cannot rename across file systems (`/opt` is not on the file system of `/usr`); revision 1maemo2 diverts into
`/usr/lib/microb-engine-orig` and drops a diversion that was recorded without the file being moved. The Makefile of the root has a `MANUAL` mechanism (an app whose Makefile has a
line starting with `MANUAL` is skipped by `make debs`, `make repo` and `make test` without APP), unused for now: `microb-engine` has no Makefile and is never built.
**Works in the real browser (2026-11-08):** after `/etc/init.d/tablet-browser-daemon.init restart` MicroB opens `https://www.seznam.cz/` with a verified certificate
(screenshot `apps/microb-nss/docs/microb-seznam-tls12.png`). Note for the restart: a prestarted engine process `browserd -s ... -n browserui` that was started before the restart survives it
(the init script does not kill it), keeps the old libraries and the browser window then waits for it forever; it has to be killed (the window respawns by itself with a new engine).
Google answers "your browser is not supported" (User-Agent sniffing, not TLS), Facebook asks for a newer browser.
**Still to do:** the User-Agent (`general.useragent.override`) and the basic HTML pages (for example `https://www.google.com/search?q=...&gbv=1`), a real use test of more sites, and (https://www.google.com, Facebook, Seznam);
then what still breaks (certificates: `ca-certs-n900` is read by MicroB; HTTP/2-only or TLS 1.3-only servers; SNI; rendering of modern pages is a different problem: Gecko 1.9.2 has no modern JavaScript).

## Not realistic
A rebuild of a modern Gecko/Firefox: it needs a far newer GTK, glib, compiler and Rust, and more RAM than the 256 MB of the phone.
