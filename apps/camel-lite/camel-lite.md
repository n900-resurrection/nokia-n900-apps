# camel-lite s OpenSSL 3 (Modest s TLS 1.2/1.3)

Systémový e-mailový klient **Modest** čte poštu knihovnou **camel-lite** (součást tinymail). Ta používá NSS 3.12.6 z prohlížeče
(`/usr/lib/microb-engine/libssl3.so`), který umí nejvýše TLS 1.0. Centrum TLS 1.0 odmítá, proto Modest hlásí "špatný port nebo nastavení".

## Řešení
Zdrojáky camel-lite jsou v repozitáři [community-ssu/tinymail](https://github.com/community-ssu/tinymail) (větev CSSU, tinymail 1.1.92,
commit je připnutý v `build.sh`). Obsahují i backend pro OpenSSL (`camel-tcp-stream-openssl.c`), ale psaný pro OpenSSL 0.9.8.
[openssl3.patch](openssl3.patch) ho převádí na OpenSSL 3:
- zrušeny zámky a callbacky pro vlákna (OpenSSL 3 je thread safe), `OPENSSL_init_ssl`,
- struktury OpenSSL jsou neprůhledné (`ssl->ctx` → `SSL_get_SSL_CTX`, `cert->valid` odstraněno),
- `TLS_client_method` s minimem TLS 1.2, SNI a kontrola jména serveru, CA balík z `/opt/curl/etc/ssl/cacert.pem`.
OpenSSL 3.5 je do knihovny přilinkovaný staticky (symboly se neexportují, aby nekolidovaly se systémovým libssl 0.9.8 v procesu Modestu).

Postup přípravy a opravy sestavení (viz `build.sh`): `libxml2-dev` do sysrootu, `AM_CONDITIONAL(OS_WIN32)`, `iconv-detect.h` se generuje
spuštěním programu pod qemu-user, `SYSTEM_MAIL_DIR` a `SENDMAIL_PATH`, `libssl` musí být v odkazu před `libcrypto`, OpenSSL se staví s `-fPIC`.

## Instalace a návrat
```sh
make -C apps/camel-lite install     # staví, balí a instaluje camel-lite-ssl3
make -C apps/camel-lite test        # 9 testů včetně TLS spojení na imap/smtp.centrum.cz
```
Soubory jsou v `/opt/camel-lite3`. `postinst` nahradí systémovou `libcamel-lite-1.2.so.0.0.0` a poskytovatele imap, smtp, pop3, local, nntp a
sendmail odkazy na ně, originály uloží jako `*.nss-orig`. **Zpět:** `make -C apps/camel-lite remove` (nebo `dpkg -r camel-lite-ssl3`) originály vrátí.
Poskytovatelé `as` a `isync` (Nokia, bez zdrojáků) zůstávají původní. Po instalaci i odinstalaci **zavři a znovu otevři Modest**
(drží starou knihovnu v paměti).

Test bez účtu: `/opt/camel-lite3/bin/camel-tlstest imap.centrum.cz 993` vypíše pozdrav serveru přes TLS.

## Nastavení účtu v Modestu
Viz [DOC/email-centrum.md](../../DOC/email-centrum.md). Po instalaci by mělo fungovat IMAP `imap.centrum.cz`, SSL (993), SMTP `smtp.centrum.cz`, SSL (465).

## Historie chyby (první verze balíčku shazovala Modest)
První verze po instalaci a restartu telefonu shazovala Modest na pozadí a neuměla se spustit. Příčina (nalezená porovnáním symbolů knihoven telefonu s novou):
1. Originální `libcamel-lite` obsahuje i `libedataserver`, `bodystruct` a `summary` (165 funkcí `e_*`, `summary_*`, `bodystruct_*`), které používá `libtinymail-camel`
   (například `e_iconv_charset_name`). Moje volba `--exclude-libs,ALL` je ze sdílené knihovny nevyexportovala. Teď se skrývá jen OpenSSL (`libssl.a:libcrypto.a`).
2. `libtinymail-camel` volá `g_thread_init`, ale `libgthread` sám nelinkuje, spoléhá na to, že ho přitáhne `libcamel-lite`. Linker nepoužité knihovny zahazuje (`--as-needed`),
   proto je v `openssl3.patch` odkaz na `g_thread_init` a `g_object_new`.
Hlavičky camel-lite z SDK a ze zdrojů CSSU jsou shodné (rozdíl struktur to není).
Prevence: `postinst` po výměně spustí `ldd -r` na všech uživatelích knihovny (libtinymail-camel, poskytovatelé imap a as) a při jakémkoli nedefinovaném symbolu
vrátí originály a instalaci odmítne; stejná kontrola je v `make test`.

## Stav a rizika
- Ověřeno: sestavení, symboly (nová knihovna má všechny `camel_*` symboly originálu kromě S/MIME a `camel_operation_cancel_prfd`, které potřebují NSS),
  TLS spojení na Centrum (IMAP i SMTP) přes novou knihovnu.
- **Neověřeno:** přihlášení a práce v samotném Modestu (vyžaduje displej), kompatibilita ABI s `libtinymail-camel` a Modestem (stejná řada 1.1.92,
  ale přeložená ze zdrojů CSSU), S/MIME (v Modestu nebude).
- Aktualizace balíčku `libtinymail-camel` z repozitáře by knihovnu vrátila na původní.
