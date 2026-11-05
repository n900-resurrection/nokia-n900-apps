# GNU Wget 1.25 (TLS 1.3) pro Maemo 5

Nahrazuje systémový `wget 1.10.2` (OpenSSL 0.9.8, jen TLS 1.0, moderní HTTPS neumí). Je linkovaný se **statickým OpenSSL 3**
(`make -C apps/openssl build`) a vlastní zlib z `apps/curl`.

```sh
make -C apps/wget install    # build (když je zastaralý), deb, scp, dpkg -i
make -C apps/wget test       # 7 testů na telefonu
wget -O - https://github.com | head
```
- Balíček se jmenuje `wget`, takže při instalaci nahradí starý. Zpět: nainstalovat `wget_1.10.2-2osso3_armel.deb`.
- Certifikáty: `/opt/curl/etc/ssl/cacert.pem` (z balíčku `curl`), nastaveno v `/opt/wget/etc/wgetrc`. Balíček závisí na `curl`.
- Bez IPv6, IDN, PCRE, gettext a libpsl.
- Při překladu: gnulib v glibc 2.5 hlásí chybějící `O_BINARY`/`O_TEXT` (doplněno `-D...=0`), a `make` musí běžet nejdřív v `lib/`, pak v `src/`.
- Ověřeno 2026-11-05: HTTPS na GitHub (200 OK), odmítnutí prošlého certifikátu, HTTP. Neověřeno: FTP, velké soubory, přesměrování přes různé servery.
