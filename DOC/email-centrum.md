# E-mail Centrum na N900

Heslo se do repozitáře nikdy nepíše. Použij **heslo pro aplikace** (v nastavení účtu Centrum), pokud ho nabízí.

## Servery (ověřeno z telefonu přes curl, 2026-11-05)
| Služba | Server | Port | Zabezpečení | Přihlášení |
|---|---|---|---|---|
| Příchozí (IMAP) | `imap.centrum.cz` | 993 | SSL/TLS (implicitní), TLS 1.3 | celá adresa `jméno@centrum.cz`, AUTH PLAIN |
| Odchozí (SMTP) | `smtp.centrum.cz` | 465 | SSL/TLS (implicitní), TLS 1.3 | totéž, AUTH PLAIN / LOGIN |

Ověřeno: IMAP přihlášení a výpis složek, SMTP přihlášení a odeslání zkušebního e-mailu (server odpověděl `250 Ok: queued`).
Neověřeno: STARTTLS na portu 587 (nezkoušeno), POP3.
Složky na serveru jsou česky v kódování IMAP (`Hromadn&AOE-` = Hromadná, `odeslan&AOE-` = odeslaná, `ko&AWE-` = koš).

## Z příkazové řádky (curl 8.23 z balíčku `curl`)
Heslo nedávej na příkazový řádek (je vidět v `ps`), předej konfiguraci přes stdin:
```sh
printf 'user = "jmeno@centrum.cz:HESLO"\nurl = "imaps://imap.centrum.cz/INBOX"\nrequest = "STATUS INBOX (MESSAGES UNSEEN)"\n' | ssh n900 'curl -sS -K -'
```
Odeslání: `url = "smtps://smtp.centrum.cz:465"`, `mail-from`, `mail-rcpt`, `upload-file = soubor.txt`
(soubor s hlavičkami From, To, Subject, Date a prázdným řádkem před textem).
Před použitím `curl` musí být správný čas, jinak selže ověření certifikátu (`ntp-sync`).

## Mutt (terminálový klient, balíčky `mutt` a `msmtp`)
Podrobně v [apps/mutt/mutt.md](../apps/mutt/mutt.md). Shrnutí: Mutt čte přes IMAP (`imaps://imap.centrum.cz/`), odesílá přes `msmtp`
(`smtp.centrum.cz:465`). Příklady konfigurace bez hesla jsou v balíčcích; heslo čtou Mutt i msmtp ze souboru `~/.msmtp-password` (práva 600), takže se Mutt neptá při každém startu. Adresář `~/.mutt` musí patřit uživateli `user`, jinak Mutt hlásí `Error opening mailbox`. Ověřeno odesláním zprávy z Muttu (TLS 1.3, `250 Ok: queued`).

## Modest (systémový klient, balíček `modest` 3.4.8)
Modest je součástí Maemo 5 (Aplikace → E-mail). Nastavení účtu:
1. Otevři E-mail a vyber přidání účtu (průvodce). Předvolba pro Centrum v databázi poskytovatelů není, zvol ruční nastavení / jiný typ účtu.
2. Typ účtu: IMAP. Příchozí server `imap.centrum.cz`, zabezpečení SSL (port 993), uživatel celá adresa.
3. Odchozí server `smtp.centrum.cz`, zabezpečení SSL (port 465), ověření ano, stejné údaje.

**Vyzkoušeno uživatelem (2026-11-05): Modest hlásí špatný port nebo nastavení, přihlášení nefunguje.** Příčina: Centrum odmítá TLS 1.0 (z telefonu `openssl s_client` dostane `tlsv1 alert protocol version` na portu 993 i 465), nastavení ani port nejsou chybně. Port 143 STARTTLS nenabízí. Řešení: [mutt-hildon](../apps/mutt-hildon/mutt-hildon.md) nebo přeložený camel-lite s OpenSSL 3 (v TODO).

Původní předpoklad: Názvy menu v průvodci jsou z paměti a mohou se lišit. Modest používá starou
knihovnu NSS (TLS jen do verze 1.0, viz DOC/roadmap.md, sekce 3) a server TLS 1.0 odmítá, takže je pravděpodobné, že
selže chybou spojení nebo certifikátu. Výsledek zkoušky prosím připiš sem.
