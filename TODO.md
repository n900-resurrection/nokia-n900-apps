# TODO

Stav k 2026-11-04. Odškrtnuté = hotovo a ověřeno, neodškrtnuté = zbývá.

## Rozpracované

- [ ] **Jak se balíček chová v Application Manageru** (`Section: user/office`, `XB-Maemo-Display-Name`).
  - Ověřeno: instalace přes `dpkg -i`, `dpkg -L`, `ldd`, spuštění z menu (ikona).
  - Zbývá: instalace z Application Manageru (ne přes `dpkg`), zobrazení v kategorii *Office*, zobrazované jméno
    a popis, chování při aktualizaci a odinstalaci, varování o nepodepsaném zdroji. `.desktop` nemá `Icon=`,
    takže menu ukazuje výchozí ikonu. Vlastní ikonu přidat (`XB-Maemo-Icon-26` v `control` + `Icon=` v `.desktop`).
- [ ] **Příprava Proxmox kontejneru** (server Zalman): LXC s nginx (HTTP, jen LAN) + reprepro nebo aptly
  pro repozitář `n900dev`, později kopie `maemo.plan9.de`. Návrh viz [DOC/packaging.md](DOC/packaging.md),
  sekce 5, a [DOC/mirror.md](DOC/mirror.md).

## Z rozboru (k potvrzení)

- [ ] Pozdější import `.deb` do repa (`reprepro includedeb`) a přidání katalogu `n900dev` v telefonu přes HTTP.
- [ ] Rozhodnout o podpisu repozitáře (vlastní GPG klíč) a ověřit, jak se starý apt 0.7.20 chová k nepodepsanému.
- [ ] Nastavit hodiny na telefonu (při testu bylo datum 1. 1. 2009).
- [ ] `chown` souborů z `scp` (patří `root`, protože se připojujeme jako root), případně připojení jako `user`.
- [ ] Doplnit `PATH` o sbin trvale i pro SSH relace (hotovo jen pro login shell: `/etc/profile.d/sbin-path.sh`).
- [ ] Zkusit `make build deb` pro jinou verzi WordGrinderu (ověřena jen 0.8), případně 0.9 (Luau, C++).
- [ ] `maemo-g++` wrapper pro C++ (zatím jen `maemo-gcc` pro C).
- [ ] htop3: balíček je sestavený (samostatný `htop3` vedle systémového 0.8.3, obálka s `-d 50` a `HTOPRC`),
  zbývá ho nainstalovat na N900 (`make -C apps/htop install`) a ověřit menu, obálku a odinstalaci.
  Viz [apps/htop/htop.md](apps/htop/htop.md). Nový htop je 2,4× náročnější na procesor.
- [ ] **Roadmapa (moderní TLS, e-mail Centrum a TUL, feedy, rádio, Audiobookshelf):** plán je v [DOC/roadmap.md](DOC/roadmap.md).
  Kalendář a kontakty i „brána na domácím serveru“ jsou z plánu vypuštěné. Čeká na odpovědi (sekce 9): adresa a formáty
  Audiobookshelfu, přihlášení TUL, pořadí uvnitř e-mailu.
- [ ] **Fáze 1 roadmapy, moderní TLS (priorita):** OpenSSL 3 staticky, `curl` s IMAP/SMTP/POP3, obnova CA balíku, test účtů Centrum a TUL
  přes `curl`, průzkum systémového TLS (Modest používá NSS, ne OpenSSL).
- [ ] **curl a git s moderním HTTPS (priorita):** balíčky `curl` (750 kB) a `git` (10 MB, nahradí `git 1.6.2-1`)
  jsou nainstalované a ověřené na N900 (klon `nokia-n900-notes` přes HTTPS za 126 s, 19 příkazů gitu OK).
  Zbývá: odinstalace/návrat ke `git 1.6.2`, `git push` přes HTTPS s tokenem, SSH klient pro `git@github.com:`. Viz [apps/curl/curl.md](apps/curl/curl.md),
  [apps/git/git.md](apps/git/git.md).
- [ ] **cmatrix, cbonsai, tty-clock:** balíčky jsou sestavené (22 kB, 95 kB, 10,5 kB). Zbývá nainstalovat na N900 a ověřit
  spouštěče v menu (`cbonsai-live`), `man`, chování na displeji. Viz [apps/cmatrix/cmatrix.md](apps/cmatrix/cmatrix.md),
  [apps/cbonsai/cbonsai.md](apps/cbonsai/cbonsai.md), [apps/tty-clock/tty-clock.md](apps/tty-clock/tty-clock.md).
- [ ] Zafixovat SHA-256 zdrojových tarballů (curl, mbedTLS, zlib, git) v build skriptech.
- [ ] `wget` s moderním TLS (nebo upravit skripty, aby volaly `curl`).
- [ ] Obalit volání `workshop exec` příkazem `timeout -k` v `mk/common.mk`: `exec` se po dokončení dlouhých
  buildů občas nevrátí (potvrzeno u toolchain, htop a curl).
- [ ] Další aplikace v `apps/<app>/` (kandidáty vybrat).
- [ ] Python 3.11: přepsat na armel a glibc 2.5, vlastní OpenSSL (SDK má jen 0.9.8n). Viz [README.md](README.md).

## Hotovo

- [x] Workshop `n900`, cross-toolchain armel, sysroot z Fremantle SDK (`maemo.plan9.de`).
- [x] `hello` přeložen a spuštěn na N900.
- [x] Všechny aplikace (wordgrinder, htop, curl, git, cmatrix, cbonsai, tty-clock) používají sdílené `mk/app.mk`
  a `scripts/debpack.sh`; po převodu vycházejí balíčky shodně (metadata i seznamy souborů).
- [x] SSH klíčem přes alias `n900`, `make push` s automatickým vytvořením složky.
- [x] WordGrinder 0.8: build, `.deb`, instalace a spuštění na N900.
- [x] `Makefile` v kořeni i v `apps/wordgrinder/`, sdílená část v `mk/common.mk`.

- [ ] Mutt jako nativní binárka (OpenSSL 3 statický), potom případně jednoduché Hildon GUI nad ním.
- [ ] Podcasty: sfeed + curl skript, později gpo (gPodder 3, Python 3). Zdroj: Audiobookshelf http://192.168.1.101:13378 (LAN, bez TLS).
- [ ] E-mail GUI: porovnat Modest (zdrojáky, TLS/NSS) a Claws Mail na 800x480. TUL odloženo.
- [ ] Python 3 pro Maemo 5 (armel, glibc 2.5, vlastní OpenSSL 3 + ssl modul): spouštění vlastních aplikací a nástrojů (gpo, skripty). Základ je repozitář Python_3.11_on_N900, přepracovat na tento build systém.
- [~] Go na N900: hello s goroutines a HTTPS (TLS 1.3) běží na telefonu, viz apps/go/go.md. Zbývá: balíček s wrapperem (SSL_CERT_FILE), vyzkoušet větší programy, paměť a běh na jednom jádru.
- [ ] Bash 5 + BusyBox 1.37 pro N900. Zařízení má bash 3.2 (a bash4 4.2.20) a busybox-power 1.23.1. Odhad: Bash je autoconf a čisté C, překlad podobný jako git (dynamicky na glibc 2.5 nebo staticky, readline vestavěný, ncurses/termcap staticky). Snadné. BusyBox 1.37 je Kbuild, překlad jde, ale glibc 2.5 nemá některá volání (utimensat, O_CLOEXEC, sync_file_range, getrandom), řeší se compat hlavičkou a vypnutím v menuconfig; doporučeno staticky, instalovat vedle systémového do /opt a nepřepisovat /bin/busybox. `wget` v BusyBoxu umí TLS jen přes vlastní `ssl_client` (jen TLS 1.2), nenahrazuje curl. Přínos: moderní awk, sed, tar, find, ash/hush. Pozor na riziko zlomit systémové skripty.
- [ ] SSL, co zbývá: (1) správný čas je podmínka ověření certifikátů, proto nainstalovat balíček ntp-sync a ověřit if-up hook a zápis RTC; (2) systémová cesta k CA: symlink /etc/ssl/certs/ca-certificates.crt na /opt/curl/etc/ssl/cacert.pem pro Go a další; (3) obnova CA bundle (cron nebo ručně curl); (4) programy s OpenSSL 3 (mutt, Python ssl) – knihovna je hotová v build/deps/openssl-3.5.9; (5) wget s moderním TLS; (6) Modest/NSS.
- [ ] Čas na N900: GUI volba automatického času používá čas operátora (NITZ přes GSM modem, clockd, CLOCKD_NET_TIME), ne NTP. Bez SIM nebo sítě operátora proto nefunguje a servery nejsou mrtvé. Ověřeno: `ntpd -w -p pool.ntp.org` (busybox) z telefonu funguje, odchylka 1,3 s. Řešení: malý skript `ntp-sync` (`ntpd -q -n -p ...` nebo vlastní SNTP) spouštěný po připojení Wi-Fi (if-up.d), jinak jen ručně; ověřit zápis do RTC přes clockd. Správný čas je nutný pro ověření TLS certifikátů.
- [ ] Instant messaging (Signal, WhatsApp, Messenger): rešerše je v DOC/messengers.md. Telefon má Pidgin 2.7.7, libpurple a telepathy-haze, takže nový protokol = libpurple plugin. Zbývá ověřit TLS vrstvu libpurple, přeložit purple-facebook / purple-gowhatsapp, vyzkoušet Rust (gurk-rs pro Signal) a Go (whatsmeow), BitlBee jako terminálová brána. Později GUI (rtcom-messaging) nebo vlastní Hildon aplikace.
- [x] Bash 5.3 (bash5) a BusyBox 1.37 (busybox37): nainstalováno a otestováno na telefonu (`make -C apps/bash test`, `make -C apps/busybox test`). Zbývá: UTF-8/locale, bash5 jako přihlašovací shell, PATH natrvalo (viz apps/busybox/busybox.md).
- [ ] ntp-sync: ověřeno ručně (posun o 300 s opraven, RTC zapsáno, hook spuštěn ručně). Neověřeno: že icd2 hook při reálném připojení Wi-Fi spustí. Man stránka se na N900 nezobrazí (chybí nroff) a Maemo ji maže (docpurge), proto je hlavní nápověda `ntp-sync -h`.
- [x] jq 1.8.2 a wget 1.25.0 (OpenSSL 3, TLS 1.3): přeložené, nainstalované, testy prošly (`make test`). Wget nahradil wget 1.10.2 (jde vrátit instalací starého .deb).
- [x] Testy pro všechny nainstalované aplikace (`make test`, 13 sad, DOC/testing.md).
- [ ] Testy: automatické spuštění po `make install`; testy pod qemu-user bez telefonu; kontrola velikosti a závislostí balíčků.
- [ ] Modest + Centrum: vyzkoušet přihlášení v GUI (DOC/email-centrum.md), výsledek zapsat. SMTP test odeslán curlem (queued), zkontrolovat, že zpráva došla do schránky.
- [x] Mutt 2.4.3 + msmtp 1.8.34 (OpenSSL 3): přeložené, nainstalované, testy prošly (`make test`). Odeslání pošty z Muttu přes msmtp na Centrum ověřeno (TLS 1.3). Mutt nemá SASL, proto SMTP přes msmtp.
- [ ] Mutt interaktivně na telefonu (nastavit ~/.muttrc a ~/.msmtprc pro uživatele `user`, přečíst INBOX, složka Odeslané, UTF-8 a čeština, ikona v menu). Vyžaduje terminál a heslo od uživatele.
- [x] Hildon GUI nad Muttem: `mutt-hildon` 0.1 nainstalován, 6 testů prošlo, aplikace běží na displeji. Zbývá vyzkoušet rozložení uživatelem a doplnit mazání, přílohy, složky, příznak přečteno.
- [x] mutt-hildon 0.2: automatické obnovování při otevřené aplikaci (Settings, výchozí vypnuto), mazání do koše, nastavení v `~/.mutt-hildon.conf`.
- [ ] mutt-hildon: démon na pozadí (obnovování a oznámení o nové poště i při zavřené aplikaci; hildon-status-menu nebo notifikace). Pozor na baterii a RAM (volných bývá ~10 MB).
- [ ] mutt-hildon: lokální cache (hlavičky a stažená těla zpráv, např. soubor nebo sqlite3 v `~/.mutt-hildon/`), aby seznam naskočil hned a šel číst offline; Mutt má `-USE_HCACHE` (bez cache hlaviček, volitelně přeložit s Tokyo Cabinet/GDBM).
- [ ] mutt-hildon: přepínání mezi e-mailovými účty (více bloků v konfiguraci, výběr účtu v menu; zatím se čte jediný účet z `~/.muttrc` a `~/.msmtprc`).
- [ ] mutt-hildon: jazykové mutace přes gettext (`_()` v kódu, `.pot`/`.po`, česky a anglicky; Python 2.5 má modul `gettext`, katalogy `.mo` jdou do `/usr/share/locale/<jazyk>/LC_MESSAGES/`). Texty v kódu jsou teď anglicky.
- [ ] mutt-hildon: doplňování adres z kontaktů telefonu. Zjištěno: kontakty jsou v `/home/user/.osso-abook/db/addressbook.db` (Berkeley DB s vCardy, čitelné `bsddb.hashopen(..., "r")` v Pythonu 2.5, jen pro čtení, existuje i `index_email.db`). Dnes jsou tam 4 kontakty a žádný nemá e-mail, takže první krok je import adres (např. z Mutt aliasů nebo ze zpráv) a čtení vCard polí EMAIL a FN pro našeptávač v poli "To".
- [x] mutt-hildon: listování do historie (menu Older messages, po 25 zprávách) hotovo v 0.1.
- [ ] mutt-hildon: další funkce: přesun do složek, příznak přečteno, složky, ukládání příloh.
- [ ] Druhá varianta e-mailu: přeložit camel-lite (Modest) s OpenSSL 3, aby systémový klient uměl TLS 1.2/1.3.
- [ ] Mutt: knihovna Cyrus SASL (nebo vlastní SMTP přes curl) jen pokud msmtp nestačí; hlavičková cache (tokyocabinet/lmdb) pokud bude IMAP pomalý.
- [x] sfeed 2.4 (fáze 3 roadmapy): přeložený, nainstalovaný, 11 testů prošlo. Zbývá: podcasty (stahování epizod, `sfeed_podcast` skript), napojení na Audiobookshelf.
- [ ] Audio (fáze 4): mpg123/cmus nebo ověřit existující `mpg123 1.12.1`/`mplayer` na zařízení, přehrání stažené epizody; `jq` je hotové.
- [ ] Audiobookshelf klient (terminál): shell skript s curl + jq proti http://192.168.1.101:13378 (login, seznam knih, stažení). Potřebuje účet od uživatele.
- [ ] Audio: zařízení už má `mplayer` (1.0svn 2009), `gst-launch-0.10` s GStreamer pluginy (ffmpeg, xiph, mkv, wma) a `mediaplayer`. Nový přehrávač (mpg123/cmus) tedy možná není potřeba: nejdřív vyzkoušet `mplayer` / `gst-launch` na MP3, M4B (AAC) a Opus staženém přes curl z Audiobookshelfu. Rozhodnout podle výsledku.
