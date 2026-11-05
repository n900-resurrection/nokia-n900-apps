# Mutt 2.4 (terminálový e-mail, TLS 1.3) pro Maemo 5

Nahrazuje `mutt 1.5.20` z repozitáře Fremantle (jen TLS 1.0, Centrum ho odmítne). Linkovaný se **statickým OpenSSL 3**
(`make -C apps/openssl build`) a se statickým `ncursesw` (UTF-8; zařízení má jen `libncurses5`). IMAP a POP3 jsou vestavěné.

**Odesílání jde přes `msmtp`** ([msmtp.md](../msmtp/msmtp.md)): Mutt přeložený bez Cyrus SASL se k SMTP serveru s přihlášením
přihlásit neumí (chyba "Could not send the message" bez dalšího vysvětlení). Balíček `mutt` proto závisí na `msmtp`.

```sh
make -C apps/mutt install    # build (když je zastaralý), deb, scp, dpkg -i (potřebuje i make -C apps/msmtp install)
make -C apps/mutt test       # 15 testů na telefonu
```

## Nastavení Centrum
1. `cp /opt/mutt/share/doc/mutt/muttrc.centrum.example ~/.muttrc` a upravit adresu (`you@centrum.cz`).
2. `cp /opt/msmtp/share/doc/msmtp/msmtprc.centrum.example ~/.msmtprc; chmod 600 ~/.msmtprc` a upravit adresu.
3. Heslo pro odesílání: `(umask 077; echo 'heslo' > ~/.msmtp-password)` (nebo smazat řádek `passwordeval` v `~/.msmtprc`).
   Heslo pro čtení (IMAP) se Mutt zeptá při prvním připojení. V repozitáři heslo nikde není.
4. `mutt`. Ikona "Mutt" je v menu (spouští se v `osso-xterm`).

## Co je ověřeno (2026-11-05)
- 15 testů (verze, IMAP/SMTP/OpenSSL v buildu, načtení příkladu konfigurace, odkaz na CA bundle, chybějící knihovny, pozdrav IMAP serveru Centra).
- **Odeslání pošty z Muttu přes msmtp na Centrum:** server přijal zprávu (`250 Ok: queued`), TLS 1.3 (`TLS_AES_256_GCM_SHA384`)
  s ověřeným certifikátem. Připojení Muttu k IMAP serveru (TLS 1.3) se také navázalo.
- Neověřeno: interaktivní čtení pošty v terminálu telefonu (IMAP seznam složek, otevření zprávy), UTF-8 v interním editoru,
  výkon na 600 MHz, POP3. Složka "Odeslané" (`+odeslan&AOE-`) se při dávkovém odeslání neuložila ("Fcc failed"), protože tehdy
  nebylo zadané IMAP heslo; v interaktivním běhu to ověřit.

## Technické poznámky
- CA certifikáty: OpenSSL v Muttu hledá `/opt/openssl/etc/ssl/cert.pem` (výchozí cesta zadaná při překladu). Balíček tam dává odkaz
  na `/opt/curl/etc/ssl/cacert.pem`. Proměnné `ssl_ca_certificates_file` Mutt 2.4.3 nemá.
- Bez hlavičkové cache (`header_cache` neexistuje), bez GPGME a bez NLS.
- Soubor licence je `COPYRIGHT` (Mutt nemá `COPYING`).
- Dokumentace Muttu (manuál) se nestaví; `mutt -h`, `man` na N900 nefunguje (chybí nroff), nápověda v programu: `?`.
