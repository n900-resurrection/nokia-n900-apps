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
- [x] Python 3.11.18 pro Maemo 5 ([apps/python3/python3.md](apps/python3/python3.md)): balíček `python3.11`, 20 testů prošlo (ssl s OpenSSL 3.5 a TLS 1.3, sqlite3 3.50, curses, threads, pty), ukázka `src/python3/hello/hello.py` běží na telefonu. Zbývá: `readline` (REPL s historií), `ctypes` (libffi), `bz2`/`lzma`/`uuid`, `pip` přes `python3 -m ensurepip` vyzkoušet, potom gpodder (`gpo`).
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
- [x] mutt-hildon 0.3: lokální cache v SQLite (seznam naskočí hned, čtení offline) a fronta neodeslaných zpráv (Refresh se je pokusí odeslat, titulek ukazuje počet).
- [ ] mutt-hildon 0.3: ručně vyzkoušet na telefonu (uživatel, až bude čas): vypnout síť, odeslat zprávu (musí skončit ve frontě, titulek `Mail (1 unsent)`), zapnout síť, Refresh (odešle ji), menu Outbox (úprava, Discard all), start aplikace bez sítě (seznam z cache), otevření uložené zprávy offline.
- [ ] mutt-hildon: cache jen pro INBOX; ostatní složky až s jejich podporou. Staré indexy zpráv v cache se opraví až po Refresh (kontrola Message-ID chrání před čtením/mazáním jiné zprávy).
- [ ] Mutt: cache hlaviček (`-USE_HCACHE`) přeložit s GDBM nebo Berkeley DB/lmdb (Mutt SQLite jako backend nemá); nízká priorita, mutt-hildon už cache má.
- [ ] mutt-hildon: přepínání mezi e-mailovými účty (více bloků v konfiguraci, výběr účtu v menu; zatím se čte jediný účet z `~/.muttrc` a `~/.msmtprc`).
- [ ] mutt-hildon: jazykové mutace přes gettext (`_()` v kódu, `.pot`/`.po`, česky a anglicky; Python 2.5 má modul `gettext`, katalogy `.mo` jdou do `/usr/share/locale/<jazyk>/LC_MESSAGES/`). Texty v kódu jsou teď anglicky.
- [x] mutt-hildon 0.4: doplňování adres v poli „To“ (`contacts.py`): vCardy z `/home/user/.osso-abook/db/addressbook.db` (pole EMAIL, jen čtení) + adresy naučené z pošty (odesílatelé v cache, příjemci odeslaných zpráv). Selftest prošel; okno s nabídkou zatím nikdo neviděl na displeji. Kontakty v telefonu mají jen telefony, e-maily je potřeba doplnit v aplikaci Kontakty.
- [x] mutt-hildon: listování do historie (menu Older messages, po 25 zprávách) hotovo v 0.1.
- [ ] mutt-hildon: další funkce: přesun do složek, příznak přečteno, složky, ukládání příloh.
- [x] Druhá varianta e-mailu: camel-lite s OpenSSL 3 (balíček `camel-lite-ssl3`, [apps/camel-lite/camel-lite.md](apps/camel-lite/camel-lite.md)): přeloženo, nainstalováno, 8 testů včetně TLS na Centrum prošlo. Ověřeno v samotném Modestu uživatelem (2026-11-05): načítání pošty z Centrum funguje, výsledek v DOC/email-centrum.md. Zbývá odeslání a S/MIME.
- [ ] Mutt: knihovna Cyrus SASL (nebo vlastní SMTP přes curl) jen pokud msmtp nestačí; hlavičková cache (tokyocabinet/lmdb) pokud bude IMAP pomalý.
- [x] sfeed 2.4 (fáze 3 roadmapy): přeložený, nainstalovaný, 11 testů prošlo. Zbývá: podcasty (stahování epizod, `sfeed_podcast` skript), napojení na Audiobookshelf.
- [ ] Audio (fáze 4): mpg123/cmus nebo ověřit existující `mpg123 1.12.1`/`mplayer` na zařízení, přehrání stažené epizody; `jq` je hotové.
- [ ] Audiobookshelf klient (terminál): shell skript s curl + jq proti http://192.168.1.101:13378 (login, seznam knih, stažení). Potřebuje účet od uživatele.
- [ ] Audio: zařízení už má `mplayer` (1.0svn 2009), `gst-launch-0.10` s GStreamer pluginy (ffmpeg, xiph, mkv, wma) a `mediaplayer`. Nový přehrávač (mpg123/cmus) tedy možná není potřeba: nejdřív vyzkoušet `mplayer` / `gst-launch` na MP3, M4B (AAC) a Opus staženém přes curl z Audiobookshelfu. Rozhodnout podle výsledku.
- [ ] YouTube: ověřit `pip install yt-dlp` a `yt-dlp -F` na telefonu, přeložit QuickJS (JavaScriptový běh pro yt-dlp), přehrávat 480p přes mpv, pak Hildon rozhraní. Rešerše v [DOC/youtube-n900.md](DOC/youtube-n900.md); staré klienty (cuteTube, MediaBox) opravovat nemá smysl.
- [ ] Hildon z Pythonu 3: tenká vrstva nad ctypes (`hildonlite.py`) podle [DOC/hildon-python3.md](DOC/hildon-python3.md); doplnit xvfb/x11vnc/imagemagick do skriptu toolchain; zkoušet i mutt-hildon (Python 2.5) na PC.
- [x] Python 3: readline, ctypes, bz2, lzma a pip hotové (30 testů); chybí jen uuid (`_uuid`), dbm, tkinter. Další krok gPodder.
- [x] QuickJS 2026-06-04 přeloženo (`make quickjs`, balíček `quickjs`, `apps/quickjs`), běží pod qemu ve Workshopu (BigInt, pojmenované skupiny, soukromá pole); na telefon zatím neinstalováno (`make -C apps/quickjs install test`).
- [x] yt-dlp 2026.10.26 + QuickJS ve Workshopu: formáty i stažení fungují (ověřeno, viz [DOC/youtube-n900.md](DOC/youtube-n900.md)).
- [x] yt-dlp 2026.10.26 + QuickJS nainstalovány na telefonu (`~/.local/bin/yt-dlp --js-runtimes quickjs:/usr/bin/qjs`), `-F` funguje. [ ] Zkusit stažení a přehrání; pak Hildon GUI (hledání, seznam, stažení do `~/MyDocs`) a přehrávání mpv/mplayer.
- [x] gPodder 2.20.3 postaven (`make -C apps/gpodder deb`, 628 kB). [x] Nainstalováno na telefon 2026-11-06 (záloha `build/backup/gpodder-config-2.20.2-*.tgz`). [ ] Ověřit v GUI; zvážit jádro 3.11 na Pythonu 3 ([DOC/gpodder-n900.md](DOC/gpodder-n900.md)).
- [x] `make hildon-run` (Python 3 i Python 2.5 + PyGTK, VNC, snímky), mutt-hildon běží na PC. hildon-desktop nejde (clutter + OpenGL ES).


- [ ] apt repozitář pro N900 (`make repo`: dists/fremantle, Packages.gz, Release s MD5Sum+SHA1, odpojený podpis Release.gpg), `apt-transport-curl` (metoda https přes curl 8, protože apt na telefonu umí jen TLS 1.0), publikace do podrepozitáře na GitHubu; `mutt-hildon` do vlastního repozitáře.
- [ ] SDK obraz (zip se sysroot a build/deps) jako release asset; `make sysroot` ho stáhne.
- [ ] **Podepisování repozitáře** (viz [DOC/apt-repo.md](DOC/apt-repo.md)): klíč GPG, `Release.gpg` (odpojený podpis, ne InRelease), klíč do `apt-key` na telefonu (ověřit formát starého apt-key), cíl `make repo-key`; podpis jen `Release`, ne každého `.deb`.
- [x] `apt-transport-curl` 0.1 hotov a nainstalován na telefonu ([apps/apt-transport-curl/apt-transport-curl.md](apps/apt-transport-curl/apt-transport-curl.md), 12 testů): metoda `/usr/lib/apt/methods/https` (protokol apt: capabilities 100, Acquire 600, odpovědi 200/201) přes `/usr/bin/curl`; balíček "malý update" pro komunitu r/N900, dokumentace.
- [ ] Rozdělit do podrepozitářů: `apps/mutt-hildon` (samostatný repozitář + `git submodule add`; v hlavním repu napřed `git rm -r --cached apps/mutt-hildon`) a `n900-repository/` (apt repozitář).
- [x] Modest 100 % CPU: čtecí smyčky camel-lite volaly `select` s nulovým časem a chyby OpenSSL se mapovaly na EINTR (opakovalo se donekonečna); oprava `apps/camel-lite/busyloop.patch`, balíček 1.1.92cssu7-2maemo1. [ ] Ověřit v běžícím Modestu.
- [ ] apt-transport-curl: `If-Modified-Since`, navázání stahování, komunitní návod pro r/N900 (instalace jedním `dpkg -i`, bootstrap: první balíček se musí stáhnout přes HTTP nebo ručně).
