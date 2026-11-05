# msmtp 1.8 (odesílání pošty, TLS 1.3) pro Maemo 5

Malý SMTP klient. Používá ho Mutt jako `sendmail` (viz [mutt.md](../mutt/mutt.md)). Linkovaný se statickým OpenSSL 3.

```sh
make -C apps/msmtp install
make -C apps/msmtp test      # 7 testů; --serverinfo ověří certifikát smtp.centrum.cz bez přihlášení a bez odeslání
```
- Konfigurace: `~/.msmtprc` (`chmod 600`), příklad bez hesla: `/opt/msmtp/share/doc/msmtp/msmtprc.centrum.example`.
- Pozor: při `ssh n900` jsi **root**, takže `~` je `/root`. Pro uživatele `user` (menu, `osso-xterm`) je to `/home/user`; konfigurace musí být v domovském adresáři toho, kdo Mutt spouští.
- Přeložení: `libssl_CFLAGS`/`libssl_LIBS` místo pkg-config, `-lrt` kvůli `clock_gettime`.
- Ověřeno: odeslání zprávy na `smtp.centrum.cz:465` (`250 Ok: queued`, `tls=on auth=on`).
