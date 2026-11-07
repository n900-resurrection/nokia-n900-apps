# TODO

Stav k 2026-11-06. Odškrtnuté = hotovo a ověřené, neodškrtnuté = zbývá. Nahoře je to, co se dělá teď, dole stručný přehled hotového.

## Teď

- [ ] **Správce aplikací na telefonu má velké problémy: balíčky z našeho repozitáře se musí instalovat přes `apt-get` v terminálu.** Zamrzá při obnově seznamu repozitářů a také při instalaci aktualizací (2026-11-07: oznámil 7 aktualizací, zůstal na „Příprava instalace, prosím čekejte“, `apt-worker` i `hildon-application-manager` jen čekaly, nic se nenainstalovalo, držel zámek dpkg a bylo ho nutné ukončit). `apt-get update` a `apt-get install` s `n900-resurrection.github.io` fungují (náš transport `apt-transport-curl`). **Investigovat a opravit:** zaseknutý `apt-worker` v `select` a nečinná metoda `https` (zapnout `/etc/apt/apt-transport-curl.debug`, log `/tmp/apt-transport-curl.log`), porovnat s původními zdroji Nokie (`apt-transport-https` s TLS 1.0 funguje?), zkusit katalog přes `.install`/`/etc/apt/sources.list.d` a jen HTTP zdroj z PC, zda se zasekává i bez našeho transportu; na telefonu chybí `strace`, zvážit jeho zabalení. Do opravy: aktualizovat z terminálu `apt-get update && apt-get upgrade`.
  ale ve Správci aplikací `apt-worker` čeká v `select` a transportu nepošle žádný požadavek (log `/tmp/apt-transport-curl.log` má jen úvodní handshake). Stejný zásek byl i s původním http mirrorem,
  takže problém není v transportu. Další krok: porovnat konfiguraci apt-workeru (jiné `Dir::*`, seznam repozitářů, katalogy v `/var/lib/hildon-application-manager/`) a zkusit `apt-worker` ručně.
  Zamrzlý Správce drží zámek dpkg, proto se balíčky zatím instalují přes `dpkg -i` / `make -C apps/<app> install` (po ukončení Správce).
- [ ] **Podpis repozitáře** (viz [DOC/apt-repo.md](DOC/apt-repo.md)): vlastní GPG klíč, `Release.gpg` (odpojený podpis, ne InRelease), klíč do `apt-key` na telefonu (`gnupg 1.4.6` a `gpgv` tam jsou; ověřit formát starého apt-key a chování apt 0.7.20 k nepodepsanému),
  cíl `make repo-key`; podpis jen `Release`, ne každého `.deb`. Dnes apt hlásí `Ign Release.gpg` a instalace chce `--force-yes`.
- [ ] **Jellyfin na N900** (nahrazuje živé YouTube; server na LAN už běží). 1) Zkouška bez kódu: zapnout na serveru DLNA plugin a ověřit, jestli se server objeví v přehrávači N900 (Média, sdílená média/UPnP) a jestli video přehraje
  (N900 zvládá H.264 baseline a MPEG-4 v nízkém rozlišení, jinak překódování na serveru). 2) Pokud DLNA nestačí: vlastní Hildon klient přes REST API Jellyfinu (přihlášení, knihovny, hledání, přehrávání transkódovaného MP4 H.264 baseline + AAC),
  HTTPS přes lokální curl proxy jako v gPodderu (`ytdlp.stream_url` v `apps/gpodder/ytdlp.patch`) a přehrávač N900 přes MAFW; server s vlastním profilem zařízení.
  3) YouTube přes server: stahování vybraných kanálů do knihovny (yt-dlp, např. Pinchflat nebo TubeSync), telefon jen přehrává (řešení výzvy YouTube trvá na telefonu kolem 4 minut, na serveru sekundy).

## Balíčky, repozitář, Správce aplikací

- [ ] **Chování balíčku ve Správci aplikací** (`Section`, `XB-Maemo-Display-Name`): ověřeno `dpkg -i`, `dpkg -L`, `ldd`, spuštění z menu. Zbývá instalace ze Správce, zobrazení v kategorii, jméno a popis, aktualizace a odinstalace, varování o nepodepsaném zdroji (závisí na položce výše).
- [ ] Rozdělit do podrepozitářů: `apps/mutt-hildon` (samostatný repozitář + `git submodule add`; v hlavním repu napřed `git rm -r --cached apps/mutt-hildon`) a `n900-repository/` (apt repozitář); po přesunu upravit URL hlavního remote.
- [ ] Rozhodnout, jak dlouho držet staré verze balíčků v `n900-repository/pool` (zatím se nemaže nic, `scripts/mkrepo.sh` jen přidává; limit GitHub Pages cca 1 GB, největší jsou python3.11 a git). Návrh: posledních několik verzí od každého balíčku.
- [ ] apt-transport-curl: `If-Modified-Since`, navázání stahování, komunitní návod pro r/N900 (instalace jedním `dpkg -i`, bootstrap: první balíček se musí stáhnout přes HTTP nebo ručně).
- [ ] SDK obraz (zip se sysroot a build/deps) jako release asset; `make sysroot` ho stáhne.
- [ ] Volitelně zrcadlo na vlastním serveru: Proxmox kontejner (server Zalman) s nginx (HTTP, jen LAN) + reprepro nebo aptly pro `n900dev`, později kopie `maemo.plan9.de`;
  pozdější `reprepro includedeb` a katalog `n900dev` v telefonu. Návrh: [DOC/packaging.md](DOC/packaging.md), sekce 5, a [DOC/mirror.md](DOC/mirror.md).
- [ ] Testy: automatické spuštění po `make install`; testy pod qemu-user bez telefonu; kontrola velikosti a závislostí balíčků.

## Emulátor Fremantle (`make emulator`, `make hildon-run APP=...`)
- [ ] **Emulátor podle screenshotů telefonu** (`make screenshots`, vzor v `screenshots/Screenshot-20261107-1048*.png`): (1) přepínač úloh = 3 sloupce karet s tmavým rámečkem, titulek vlevo, oranžový křížek vpravo, živý náhled okna; vlevo nahoře oranžová ikona „všechny aplikace“ (mřížka 3x3), (2) plocha = tapeta + widgety (Konverzace s počty, panel zpráv, zkratky kontakty/telefon/zprávy) a nahoře hodiny a stavové ikony, vlevo nahoře ikona přepínače, (3) všechny aplikace = mřížka 5 sloupců ikon s popiskem přímo nad tapetou (bez karet/rámečků), (4) ikona přepínače v liště mění tvar podle režimu (plocha/aplikace).

Základ je hotový, viz [DOC/hildon-python3.md](DOC/hildon-python3.md) (hildon-desktop jako takový nejde: clutter + OpenGL ES). Zbývá:
- [ ] **Widgety plochy** (hodiny, kalendář, přehrávač, zkratky): náhrada za hildon-desktop. Plocha je dnes jen tapeta a horní lišta. Rozmyslet jednoduchý model (okna GTK3 bez rámu nad tapetou, nebo vykreslení do kořenového okna),
  první widgety: hodiny a ovládání přehrávače podle mocku MAFW.
- [ ] Virtuální klávesnice a vstupní metoda (zatím jen klávesnice hostitele).
- [ ] Titulková lišta a stavová oblast (stav sítě, baterie, hodiny, oznámení), Menu v titulku místo samostatného tlačítka.
- [ ] Další D-Bus mocky (osso, MAFW přehrávání se stavem a pozicí, oznámení); ověřit Menu/Back u gPodderu.
- [ ] Otevření terminálu z aplikací (osso-xterm není v emulátoru: tlačítko „Open Mutt“ v mutt-hildon).
- [ ] Hildon z Pythonu 3: tenká vrstva nad ctypes (`hildonlite.py`) podle [DOC/hildon-python3.md](DOC/hildon-python3.md); doplnit xvfb/x11vnc/imagemagick do skriptu toolchain.

## Aplikace na telefonu

- [ ] **htop3, cmatrix, cbonsai, tty-clock:** nainstalované, zbývá ověřit spouštěče v menu (`cbonsai-live`), obálku htop3 (`-d 50`, `HTOPRC`), `man`, chování na displeji a odinstalaci. Viz [apps/htop/htop.md](apps/htop/htop.md), [apps/cmatrix/cmatrix.md](apps/cmatrix/cmatrix.md), [apps/cbonsai/cbonsai.md](apps/cbonsai/cbonsai.md), [apps/tty-clock/tty-clock.md](apps/tty-clock/tty-clock.md). Nový htop je 2,4× náročnější na procesor.
- [ ] git: odinstalace/návrat ke `git 1.6.2`, `git push` přes HTTPS s tokenem, SSH klient pro `git@github.com:`. Viz [apps/git/git.md](apps/git/git.md).
- [~] Go: hello s goroutines a HTTPS (TLS 1.3) běží na telefonu ([apps/go/go.md](apps/go/go.md)). Zbývá balíček s wrapperem (`SSL_CERT_FILE`), větší programy, paměť a běh na jednom jádru.
- [ ] Bash 5 jako přihlašovací shell, UTF-8/locale, PATH natrvalo (viz [apps/busybox/busybox.md](apps/busybox/busybox.md)).
- [ ] gPodder: ověřit v GUI přidání YouTube kanálu a stažení videa do fronty (stažení funguje na úrovni modulů); zvážit jádro 3.11 na Pythonu 3 ([DOC/gpodder-n900.md](DOC/gpodder-n900.md)).
- [ ] Audiobookshelf klient (terminál): shell skript s curl + jq proti `http://192.168.1.101:13378` (login, seznam knih, stažení). Potřebuje účet od uživatele. Přehrávání: telefon má `mplayer`, `gst-launch-0.10` a `mediaplayer`
  (přehrávání z gPodderu funguje), nový přehrávač tedy asi není potřeba; vyzkoušet MP3, M4B (AAC) a Opus staženém přes curl.
- [ ] Instant messaging (Signal, WhatsApp, Messenger): rešerše je v [DOC/messengers.md](DOC/messengers.md). Telefon má Pidgin 2.7.7, libpurple a telepathy-haze, takže nový protokol = libpurple plugin. Zbývá ověřit TLS vrstvu libpurple,
  přeložit purple-facebook / purple-gowhatsapp, vyzkoušet Rust (gurk-rs) a Go (whatsmeow), BitlBee jako terminálovou bránu; později GUI nebo vlastní Hildon aplikace.

## E-mail

- [ ] Modest + Centrum: čtení pošty funguje (camel-lite-ssl3, výsledek v [DOC/email-centrum.md](DOC/email-centrum.md)); zbývá odeslání, S/MIME a ověřit v běžícím Modestu opravu 100% CPU (`busyloop.patch`). SMTP test curlem odeslán (queued), zkontrolovat doručení.
- [ ] Mutt interaktivně na telefonu (`~/.muttrc` a `~/.msmtprc` pro uživatele `user`, INBOX, složka Odeslané, UTF-8 a čeština, ikona v menu). Vyžaduje terminál a heslo od uživatele.
- [ ] mutt-hildon 0.3: ručně vyzkoušet offline (vypnout síť, odeslat zprávu = fronta, titulek `Mail (1 unsent)`, zapnout síť, Refresh ji odešle, menu Outbox, start bez sítě ze cache, uložená zpráva offline) a okno s doplňováním adres v „To“.
- [ ] mutt-hildon: přepínání účtů (více bloků v konfiguraci), přesun do složek, příznak přečteno, složky (cache zatím jen INBOX), ukládání příloh, démon na pozadí s oznámením (pozor na baterii a RAM, volných bývá ~10 MB).
- [ ] mutt-hildon: gettext (`_()` v kódu, `.pot`/`.po`, česky a anglicky; Python 2.5 má `gettext`, katalogy `.mo` do `/usr/share/locale/<jazyk>/LC_MESSAGES/`); texty jsou teď anglicky.
- [ ] Nízká priorita: Mutt hlavičková cache (`-USE_HCACHE` s GDBM/lmdb), Cyrus SASL nebo SMTP přes curl, jen pokud msmtp nebo IMAP nestačí. TUL odloženo.

## Systém a sítě

- [ ] **Čas:** hodiny telefonu bývají špatně (při testu 1. 1. 2009). GUI volba automatického času používá čas operátora (NITZ, clockd), ne NTP, takže bez SIM nefunguje. Balíček `ntp-sync` je nainstalovaný a ověřený ručně (posun 300 s opraven, RTC zapsáno);
  neověřeno, že hook icd2 spustí skript při skutečném připojení Wi-Fi. Správný čas je podmínka ověření certifikátů. Man stránka se na N900 nezobrazí (chybí nroff), hlavní nápověda je `ntp-sync -h`.
- [ ] SSL: systémová cesta k CA (symlink `/etc/ssl/certs/ca-certificates.crt` na `/opt/curl/etc/ssl/cacert.pem` pro Go a další), obnova CA bundle (cron nebo ručně curl), Modest/NSS.
- [ ] `chown` souborů z `scp` (patří `root`, protože se připojujeme jako root), případně připojení jako `user`; `PATH` se sbin trvale i pro SSH relace (hotovo jen pro login shell: `/etc/profile.d/sbin-path.sh`).

## Build

- [ ] Zafixovat SHA-256 zdrojových tarballů (curl, mbedTLS, zlib, git) v build skriptech (ranger je už ověřený).
- [ ] Obalit volání `workshop exec` příkazem `timeout -k` v `mk/common.mk`: `exec` se po dokončení dlouhých buildů občas nevrátí (potvrzeno u toolchain, htop a curl).
- [ ] `maemo-g++` wrapper pro C++ (zatím jen `maemo-gcc` pro C); WordGrinder 0.9 (Luau, C++), ověřena jen 0.8.
- [ ] Další aplikace v `apps/<app>/` (kandidáty vybrat).
- [ ] Roadmapa ([DOC/roadmap.md](DOC/roadmap.md)): čeká na odpovědi (sekce 9): adresa a formáty Audiobookshelfu, přihlášení TUL, pořadí uvnitř e-mailu. Kalendář a kontakty i „brána na domácím serveru“ jsou z plánu vypuštěné.

## Hotovo
- [x] `vim9 9.2.1302-1maemo1` (příkaz `vim9`, `/opt/vim9`, vim 7.2 a `vi` zůstávají) a `nano 9.3-1maemo1` (`/opt/nano`, ncursesw staticky, UTF-8, kolem 2 MB): `apps/vim9`, `apps/nano`, ikony přes `make icon`, testy na telefonu (vim9 11, nano 9), obě aplikace kreslí v terminálu (ověřeno v pty). Oba balíčky a `sfeed 2.4-1maemo3` jsou v `n900-repository`, čekají na commit a `apt-get update && apt-get upgrade`. Nápad: ranger `EDITOR=vim9`.
- [x] Feeds z menu padalo kvůli `xargs -P` v `sfeed_update` (busybox 1.23): opraveno v `sfeed 2.4-1maemo3`, pauza při chybě v `sfeed-reader`, 13 testů projde; zbývá potvrdit z menu na telefonu.
- [x] Repo: `pool/main/<balíček>/<balíček>_<verze>_armel.deb` (jeden adresář na balíček, bez písmen a bez free/non-free, jen `.deb`); `mkrepo.sh` při běhu přesune i soubory ze starého plochého uspořádání, `dists` se vygenerovalo znovu (36 balíčků, beze změny obsahu).
- [x] `make screenshots` kopíruje snímky z telefonu (`MyDocs/.images/Screenshots`) do `screenshots/` (v `.gitignore`).

**Základ a prostředí**
- [x] Workshop `n900`, cross-toolchain armel, sysroot z Fremantle SDK (`maemo.plan9.de`), `hello` na N900, SSH klíčem přes alias `n900`, `make push`.
- [x] Sdílené `mk/common.mk`, `mk/app.mk` a `scripts/debpack.sh` pro všechny aplikace; testy na telefonu (`make test`, [DOC/testing.md](DOC/testing.md)).
- [x] OpenSSL 3 staticky; Python 3.11.18 ([apps/python3/python3.md](apps/python3/python3.md), balíček `python3.11`, readline, ctypes, bz2, lzma, pip; chybí `uuid`, `dbm`, tkinter); QuickJS 2026-06-04 (`quickjs`).

**Balíčky pro N900** (všechny nainstalované na telefonu)
- [x] ranger `rifle.conf` pro telefon (`1maemo3`): obrázky, PDF, HTML, audio a video se otevírají v aplikacích telefonu přes D-Bus `mime_open` (`hildon-open`), náhrada `file(1)` (telefon ho nemá, starý busybox bez `od -t`), 21 testů prošlo. Ověřeno: Image Viewer; Media Player a PDF Viewer zkusit ručně (stejné volání).
- [x] Ikony menu a Správce aplikací (`1maemo2`, čeká na ověření po `apt-get upgrade`): cbonsai, cmatrix, mutt, ranger, sfeed, tty-clock mají vlastní ikony (`make icon` v aplikaci: nástroj `apps/<app>/make-icon.sh` → `icon.png`, balíček na něm závisí, společný vzhled v `scripts/icon-lib.sh`), htop3 a WordGrinder ikonu svého projektu;
  `debpack_desktop` je instaluje do `hicolor/48x48` a `64x64`, přidá `Icon=` a `XB-Maemo-Icon-26`. Opraveno: `make debs APP="a b"` předávalo `APP` do podřízených make (`override APP :=` v Makefilech aplikací).
- [x] curl 8.23 a git 2.56 s moderním HTTPS (klon přes HTTPS, 19 příkazů gitu OK), wget 1.25, jq 1.8.2 ([apps/curl/curl.md](apps/curl/curl.md), [apps/git/git.md](apps/git/git.md)).
- [x] Bash 5.3 (`bash5`), BusyBox 1.37 (`busybox37`); WordGrinder 0.8; htop3 3.5.3; cmatrix, cbonsai, tty-clock; sfeed 2.4; ranger 1.9.4 ([apps/ranger/ranger.md](apps/ranger/ranger.md), 8 testů prošlo, běží pěkně).
- [x] `ntp-sync` 0.2 (oprava času přes NTP, zápis RTC).

**E-mail**
- [x] Mutt 2.4.3 + msmtp 1.8.34 (OpenSSL 3, odeslání přes Centrum ověřeno); `mutt-hildon` 0.4 (Hildon GUI, automatické obnovování, mazání, SQLite cache a fronta neodeslaných zpráv, doplňování adres, listování historií).
- [x] `camel-lite-ssl3` ([apps/camel-lite/camel-lite.md](apps/camel-lite/camel-lite.md)): Modest čte poštu z Centrum přes TLS 1.2+ (ověřeno 2026-11-05); oprava 100% CPU v `busyloop.patch`.

**Podcasty, audio, YouTube**
- [x] gPodder 2.20.3 s `ytdlp.patch` (balíček `2maemo4`): HTTPS feedy a stahování přes curl, streamování podcastů přes lokální HTTP proxy s názvem epizody a přetáčením, přehrávač N900 hraje na pozadí a ovládá se z widgetu.
  Ověřeno uživatelem na telefonu 2026-11-06 (Podcast Živě).
- [x] YouTube na telefonu omezen na minimum (rozhodnuto 2026-11-06): žádné streamování (gPodder ukáže hlášku „stáhni nejdřív“), jen stažení videa do fronty. yt-dlp + QuickJS řeší výzvu YouTube 257 a 260 s, cache nepomáhá, klienti bez JavaScriptu nefungují
  (`android_vr` dává 403, `ios`/`mweb`/`web_safari`/`tv` žádné formáty), QuickJS drží přes 110 MB RAM. Dál YouTube na telefonu nevyvíjet, viz Jellyfin. Rešerše: [DOC/youtube-n900.md](DOC/youtube-n900.md).

**Repozitář**
- [x] apt repozitář na GitHub Pages (`make repo`: `dists/fremantle`, `Packages.gz`, `Release` s MD5Sum+SHA1+SHA256; `pool/` se zachovává včetně starých verzí) a `apt-transport-curl` 0.1 (metoda `https` přes curl 8, 12 testů, [apps/apt-transport-curl/apt-transport-curl.md](apps/apt-transport-curl/apt-transport-curl.md)).
  `apt-get update` a instalace z něj na telefonu fungují.

**Emulátor** (viz [DOC/hildon-python3.md](DOC/hildon-python3.md))
- [x] `make emulator` / `make hildon-run APP=<app>`: matchbox, horní lišta s ikonami Fremantlu (Apps, Menu, Back), tapeta, přepínač aplikací (spuštěné s náhledem a zavřením, nainstalované s ikonami z balíčků), automatické načítání aplikací z `build/deb/*.deb`, D-Bus mocky (`com.nokia.icd`, MAFW),
  spouštění balíčků pod qemu-user (htop, CMatrix, WordGrinder, gPodder, ranger), `make hildon-run` pro Python 3 i Python 2.5 + PyGTK (mutt-hildon s testovacími daty).
