# Plán: e-mail, feedy a podcasty, kontakty a kalendář, rádio a audioknihy na N900

Stav k 2026-11-04. Rešerše a plán, nic z toho zatím není implementováno. Značení: **[ověřeno]** = zjištěno z indexů
repozitářů, zdrojů nebo přímo na telefonu; **[odhad]** = můj závěr bez zkoušky; **[ověřit]** = je potřeba vyzkoušet.
Související: [packaging.md](packaging.md), [mirror.md](mirror.md), [../TODO.md](../TODO.md).

## 1. Cíle

Z jednoho zdroje: kromě telefonu chce člověk na N900 rozumně bezpečně **(a)** e-mail, **(b)** feedy a podcasty,
**(c)** synchronizaci kontaktů a kalendářů a **(d)** poslech internetového rádia, audioknih a podcastů.

Zadání navíc: terminálové nástroje všude, kde to jde, a GUI ekvivalent, který běží na omezeném HW; zjistit, jaké zdroje už existují; případně napsat vlastní nativní aplikaci s Hildonem.

Omezení zařízení **[ověřeno]**: Cortex-A8 600 MHz, **245 MB RAM** (volných bylo 59 MB), swap 786 MB, kořenový oddíl 62 MB volných, `/home` 1,1 GB volných, Python 2.5.4, glibc 2.5, jádro 2.6.28, OpenSSL 0.9.8n, OpenSSH 5.1.

## 2. Hlavní překážka: TLS

Telefon umí jen TLS 1.0 (OpenSSL 0.9.8n). Moderní IMAP, SMTP, CalDAV i weby ho odmítají. Týká se to **všech hotových aplikací** (Modest, Claws Mail, alpine, mutt 1.5, gPodder, SyncEvolution), protože linkují systémový OpenSSL/GnuTLS.
Řešení jsou dvě a doplňují se:

| | Co to je | Pro | Proti |
|---|---|---|---|
| **A. Moderní TLS na telefonu** | Vlastní nové programy staticky s OpenSSL 3 nebo mbedTLS (jako náš `curl` a `git`) | Funguje kdekoli, i mimo domov; terminálové nástroje | GUI aplikace z Extras zůstanou na starém TLS, dokud se nepřeloží znovu; tajemství (hesla) jsou na telefonu |
| **B. Brána na Proxmoxu** | Server stahuje a odesílá přes moderní TLS a telefonu nabízí obyčejné služby přes HTTP/IMAP/CalDAV v lokální síti | Funguje hned s **původním GUI** (Modest, vestavěný Kalendář a Kontakty, gPodder, Media Player); hesla zůstávají na serveru | Jen doma (Wi-Fi) nebo přes tunel; vlastní služby je potřeba udržovat |

**Doporučení:** stavět **obojí**. B je rychlé vítězství pro GUI. A je potřeba pro terminálové nástroje a pro nezávislost na domácí síti. **[odhad]**

Přístup mimo domov: WireGuard jádro 2.6.28 nemá. Zbývá SSH tunel (klient OpenSSH 5.1 na telefonu, server musí
povolit staré algoritmy, **[ověřit]**) nebo vystavit službu přes naši nově přeloženou TLS 1.2+ komunikaci
(`curl` umí, GUI aplikace ne). **Otevřená otázka**, viz sekce 8.

## 3. Co už existuje [ověřeno z indexů Fremantle repozitářů]

Zdroj: `extras`, `extras-testing`, `extras-devel` na `maemo.plan9.de`. Zdrojové balíčky jsou u všech v
`dists/fremantle/free/source/Sources.gz` (v `extras` 2 054 balíčků), takže kód hotových aplikací lze přečíst a přeložit
znovu.

| Oblast | Terminálové | GUI (Hildon/GTK/Qt) | Poznámka |
|---|---|---|---|
| **E-mail** | `mutt 1.5.20`, `alpine 2.00`, `offlineimap 6.2.1`, `dovecot 1.2.11` (server!) | **Modest 3.4.8** (systémový), `claws-mail 3.7.3` | Všechno na starém TLS. `msmtp`, `isync`, `neomutt` v repu **nejsou** |
| **Feedy a podcasty** | **nic terminálového** (`python-feedparser` je jen knihovna) | `gpodder 2.20.2`, `feedingit 0.9.1`, `feedcircuit`, `cutenews`, `feedhandler` | `libmicrofeed*` je knihovna pro feedy |
| **Kontakty a kalendář** | `gcalcli 2.1`, `syncevolution 1:1.3-1` (CLI) | vestavěný Kalendář a Kontakty, `erminig` (Google Calendar), `gpe-calendar`, `gpe-contacts` | SyncEvolution má pro Maemo 5 vlastní zálohy (kalendář přes sqlite, kontakty přes EDS) **[ověřeno z historie projektu]**; `vdirsyncer`, `khal`, `radicale` v repu **nejsou** |
| **Rádio a audioknihy** | `cmus 2.4.0`, `mpg123 1.12.1`, `mpc`, `ncmpc 0.24`, `mplayer` | vestavěný Media Player (MAFW), `internetradioplayer`, `msoma` (SomaFM), `mediabox`, **`panucci 0.99.3`** (audioknihy, podcasty), `nqaap` (audioknihy), `gpodder` | `ogg-support` rozšiřuje GStreamer; `mpd`, `moc`, `vlc` chybí |
| **Jazyky** | | `python3 3.4.0` (!), `python-hildon 0.9.0`, Python 2.5 v systému | Python 3.4 je v Extras; jeho existence souvisí s naším repozitářem `Python_3.11_on_N900` |

Co je na telefonu **[ověřeno]**: PulseAudio 0.9.15 s Nokia moduly, GStreamer 0.10 (včetně `ffmpeg`, `plugins-bad/good`),
`gst-launch-0.10`, `aplay`, `paplay`, `pactl`, ALSA, Modest 3.4.8, `libosso-abook`, EDS addressbook, kalendář
(`calendar-backend`), `libhildon1 2.2.23`, GTK 2.14.7.

### Zdrojové kódy

| Zdroj | Co v něm je |
|---|---|
| Mirror Extras: `pool/fremantle/free/source/<písmeno>/<balíček>` | Zdrojáky hotových aplikací: gpodder (2.3 a 2.20), panucci, claws-mail, alpine, cmus, syncevolution, mediabox, nqaap, erminig a stovky dalších **[ověřeno, že indexy existují; obsah balíčků jsem neprošel]** |
| GitHub `maemo-leste/*` | Hildon a systémové součásti: `libhildon`, `hildon-desktop`, `hildon-application-manager`, `hildon-*` (motivy, IM), `modest` (větev `PR1.3`), `syncevolution` (větev `maemo/be…`), `calendar-backend`, `libconic`, `connui-*`, `dsme`, `clockd` **[ověřeno, repozitáře existují]**. Je to port na Debian, takže kód je novější než Fremantle, ale vychází z něj |
| GitHub `gpodder/gpodder` | Aktuální gPodder (větve včetně `adaptive`). Maemo 5 verze 2.x je v Extras zdrojích |
| GitHub `pohly/syncevolution` (zrcadlo) | SyncEvolution, historie podpory Maemo 5/N900 od verze 0.9.2/1.0 (2010) |
| maemo.org wiki *N900 Resources*, *Maemo 5 Developer Guide* | Dokumentace vývoje, přehledy zdrojů |
| `denjhang/Maemo_N900` | Jeden osobní projekt s cross-toolchainem pro Fremantle a poznámkami |

`thp/gpodder` a `thp/panucci` na GitHubu **neexistují** (původní autor je zřejmě přesunul); jejich Fremantle verze jsou ale
ve zdrojových balíčcích v mirroru.

## 4. Terminálové nástroje: výběr a proveditelnost

Pravidlo z `packaging.md`: dynamicky se systémovou knihovnou, jen když ji telefon opravdu má; jinak staticky.
Společný základ pro všechny níže je **moderní TLS knihovna** (viz fáze 1).

### E-mail

| Nástroj | Jazyk | TLS | Verdikt |
|---|---|---|---|
| **mutt 2.x** | C, ncurses | OpenSSL nebo GnuTLS; IMAP a SMTP má v sobě | **Doporučeno.** Jedna binárka, žádný externí fetcher. Nutné OpenSSL 3 staticky |
| neomutt | C | OpenSSL/GnuTLS | Podobné, větší a závislé na víc knihovnách **[odhad]** |
| msmtp | C | GnuTLS/OpenSSL/libtls | Potřeba jen pokud nechceme SMTP v muttu |
| isync (mbsync) | C | OpenSSL | Offline kopie pošty (Maildir), **[odhad]** dobré pro velké schránky |
| aerc | Go | vlastní | **Ne** (Go dnes vyžaduje novější jádro než 2.6.28) **[odhad]** |
| alpine 2.00 | C | staré TLS | V repu je, stačí znovu přeložit s novým TLS |

Přihlášení: Gmail a podobní vyžadují **OAuth2 (XOAUTH2)** nebo heslo aplikace. mutt umí `oauth_refresh_command`
(vyžaduje externí skript). Bezpečnější a pro telefon jednodušší je vlastní IMAP přes bránu B. **[ověřit]**

### Feedy a podcasty

| Nástroj | Verdikt |
|---|---|
| **sfeed** (+ `sfeed_curses`) | **Doporučeno.** Několik malých C programů bez závislostí kromě libc a ncurses, feed se stahuje naším `curl`em. Ideální pro 245 MB RAM **[odhad, z mé znalosti projektu; ověřit]** |
| newsboat | Od určité verze vyžaduje **Rust** (aktuálně ≥ 1.90) **[ověřeno z changelogu]**, tedy cross-překlad Rustu pro armv7 s glibc 2.5 / jádrem 2.6.28. Velmi rizikové, odložit |
| snownews, canto, podfox, castero | Buď nejsou v repu, nebo chtějí Python 3 novější než 3.4 **[odhad]** |
| **podcasty** | `sfeed` + `curl` (stažení příloh) + `mpg123`/`cmus`; jednoduchý shell skript pro frontu stahování a pozici přehrávání |

### Rádio, podcasty, audioknihy

| Nástroj | Verdikt |
|---|---|
| **mpg123** (nový) | Malý C přehrávač; HTTPS proud: `curl -s URL \| mpg123 -`. Výstup přes PulseAudio (`-o pulse`) **[ověřit]** |
| **cmus** (nový, dnes 2.4 → 2.12) | Konzolový přehrávač s knihovnou, ovládání z terminálu; je v repu 2.4.0, nový by měl víc kodeků |
| GStreamer z příkazové řádky | Už na telefonu: `gst-launch-0.10 fdsrc ! decodebin ! pulsesink` jako dekodér pro `curl`; využívá dekodéry od Nokie (AAC, WMA) **[ověřit]** |
| mpd + ncmpc | MPD je C++17, těžší a síťový démon. Pro jeden telefon zbytečné **[odhad]** |
| audioknihy | `panucci` (GUI, pamatuje pozici), v terminálu `cmus`/`mpg123` + skript, který ukládá pozici |

### Kontakty a kalendář

| Nástroj | Verdikt |
|---|---|
| **SyncEvolution 1.3** (v repu) | **Jediná hotová cesta** k CalDAV/CardDAV s vestavěným Kalendářem a Kontakty **[ověřeno, že balíček existuje]**. Používá libneon s TLS 1.0, takže přes bránu B (HTTP v LAN) nebo po novém překladu |
| `gcalcli` | Jen Google Calendar, Python 2, Google dnes vyžaduje OAuth **[odhad]** |
| vdirsyncer + khal + khard | Čistě terminálové, ale Python 3 novější než 3.4 **[odhad]**. Možná jednodušší vlastní malý nástroj (viz fáze 4) |
| server | **Radicale** nebo Nextcloud na Proxmoxu; pro telefon HTTP v LAN |

## 5. GUI ekvivalenty na slabém HW

Už hotové a použitelné (**[ověřeno, že existují]**; jejich chování na 245 MB RAM zkoušet): Modest (e-mail),
gPodder 2.20 (podcasty), Panucci a nqaap (audioknihy), Media Player a `internetradioplayer` (rádio),
`cutenews`/`feedingit` (feedy). Slabina je jen TLS (sekce 2) a stáří. U každého je rozhodnutí: nechat a obejít
přes bránu B, přeložit znovu s novým TLS (zdrojáky jsou v mirroru), nebo nahradit vlastním.

## 6. Nativní aplikace s Hildonem

Technologie **[ověřeno ze systému telefonu a z indexů]**:

| Volba | Co to je | Pro | Proti |
|---|---|---|---|
| **C + GTK 2.14 + Hildon (`libhildon-1` 2.2)** | Nativní, nejmenší nároky na RAM, přesně styl systému | Nejmenší, nejrychlejší, máme `-dev` balíčky v sysrootu (`libhildon1-dev`, `libgtk2.0-dev`) | Ruční správa paměti |
| **Vala → C** | Vyšší jazyk generující C pro GTK2/Hildon | Příjemnější psaní | Potřeba Vala a vapi pro `hildon-1` **[ověřit]** |
| **Python 2.5 + `python-hildon`** | PyMaemo | Rychlý vývoj, spousta existujících příkladů (gPodder 2) | Python 2.5 je mrtvý, vyšší paměť i start, TLS 1.0 |
| **Qt 4.7 (Maemo 5)** | Qt s pluginem pro Hildon | Moderní API, QtMobility (multimédia, poloha) v Extras jako `libqtm-12-*` | Těžší za běhu; Qt samotné jsem v Extras indexu nenašel, patří do systémových repozitářů **[ověřit]** |

**Doporučení:** C + GTK2 + Hildon (případně Vala) pro vlastní aplikace. Python jen pro prototypy.

Vývojová smyčka ve Workshopu **[ověřit]**: překlad našim `maemo-gcc` proti sysrootu (hlavičky a `.pc` soubory jsou v
`sysroot/usr/lib/pkgconfig`, bude potřeba `PKG_CONFIG_SYSROOT_DIR`); zkouška v **Xephyr + qemu-user** (ARM aplikace s ARM
knihovnami ze sysrootu mluví s X serverem v kontejneru) bez telefonu; zabalení `scripts/debpack.sh`. Pokud
bude Hildon pod qemu nespolehlivý, zůstane zkouška na zařízení přes `make push install run`.

Vzory ke čtení: zdroje `gpodder`, `panucci`, `claws-mail`, `mediabox` z mirroru, Hildon z `maemo-leste/libhildon`, dokumentace
*Maemo 5 Developer Guide* (aplikace, menu, ikony, Debian balení).

## 7. Plán po fázích

Pořadí je od základů k výsledkům. Odhad práce: **S** = hodiny, **M** = den, **L** = několik dní. **[odhad]**

### Fáze 1: základy (nutné pro vše ostatní)

| # | Úkol | Práce | Výsledek |
|---|---|---|---|
| 1.1 | Moderní TLS knihovna jako znovupoužitelná závislost: **OpenSSL 3.x** staticky v `build/deps` (curl má mbedTLS, mutt/msmtp/isync chtějí OpenSSL) | M | `build/deps/openssl-*`, ověřený TLS 1.3 klient |
| 1.2 | Proxmox LXC: nginx + reprepro (vlastní repozitář), viz `packaging.md` sekce 5 | M | Katalog `n900dev` dostupný telefonu přes HTTP |
| 1.3 | Rozbalit a zkontrolovat zdrojové balíčky z mirroru (gpodder, panucci, claws-mail, alpine, cmus, syncevolution) | S | Víme, co lze znovu přeložit |
| 1.4 | Rozhodnout, jaké účty a služby použít (sekce 8) | | Vstup pro fázi 2 |

### Fáze 2: rychlé výsledky přes bránu (GUI funguje hned)

| # | Úkol | Práce | Cíl |
|---|---|---|---|
| 2.1 | **Radicale** na Proxmoxu (HTTP v LAN) + **SyncEvolution 1.3** z Extras na telefonu | M | Vestavěný Kalendář a Kontakty se synchronizují s vlastním serverem |
| 2.2 | **IMAP brána**: `mbsync`/`offlineimap` stahuje z poskytovatele, **Dovecot** nabízí telefonu lokálně; SMTP přes lokální Postfix/msmtp relay | L | **Modest** posílá a čte poštu bez TLS 1.2 na telefonu |
| 2.3 | **Podcasty a feedy na serveru**: stahování příloh, statický HTTP server, RSS pro gPodder | M | gPodder bere epizody z lokální brány |
| 2.4 | **Proxy rádiových proudů** (HTTPS → HTTP přes nginx/ffmpeg) | S až M | Media Player a `internetradioplayer` hrají rádia, která jsou jen na HTTPS |

### Fáze 3: terminálové nástroje přímo na telefonu

| # | Úkol | Práce |
|---|---|---|
| 3.1 | **sfeed** + skript pro podcasty (využívá `curl`, `mpg123`) | S |
| 3.2 | **mpg123** nový, **cmus** nový (`apps/<app>`, `mk/app.mk`) | S až M |
| 3.3 | **mutt 2.x** s OpenSSL (IMAP i SMTP v jedné binárce), případně **alpine** | M |
| 3.4 | `msmtp`/`isync` jen pokud mutt nestačí | M |
| 3.5 | Skript pro audioknihy s pamatováním pozice | S |

### Fáze 4: vlastní nativní aplikace v Hildonu

| # | Úkol | Práce |
|---|---|---|
| 4.1 | „Hello Hildon“: strom `apps/hello-hildon`, překlad proti sysrootu, zkouška v Xephyr + qemu, balíček s ikonou a `.desktop` | M |
| 4.2 | Průzkum, co z hotových GUI (gPodder, Panucci) nahradit a co jen přeložit znovu | S |
| 4.3 | Jeden užitečný nástroj na míru, např. **čtečka feedů a podcastů** nad `sfeed`, nebo ovladač brány (stav synchronizace) | L |

### Zásady napříč fázemi

- **Bezpečnost:** ověřování certifikátů vždy zapnuté, CA balík z balíčku `curl`; hesla ne v čitelných souborech
  (práva 600), po fázi 2 hesla poskytovatelů jen na serveru; oddělený účet nebo heslo aplikace pro telefon.
  Telefon nemá šifrování úložiště a běží na něm zastaralé jádro, ber to jako **nedůvěryhodné zařízení**.
- **Každá aplikace** v `apps/<app>/`, balíček přes `scripts/debpack.sh`, ověření na telefonu a dokument `<app>.md`.
- **Nic se neinstaluje bez tvého svolení** a vždy se zapíše, jak se vrátit.

## 8. Otevřená rozhodnutí (potřebuju od tebe)

1. **Poskytovatelé:** jaký e-mail (Gmail s OAuth, vlastní doména s heslem aplikace, jiný)? Jaký kalendář (vlastní Radicale/Nextcloud)?
2. **Kde bude brána** (kontejner na Proxmoxu Zalman) a jestli má být dostupná i mimo domácí síť. Pokud ano, kudy
   (SSH tunel s kompatibilním serverem, nebo se spokojíme s Wi-Fi doma)?
3. **Pořadí:** jdeme nejdřív rychlými výsledky přes bránu (fáze 2), nebo terminálovými nástroji (fáze 3)?
   Já bych začal fází 1.1 a 1.2 a pak fází 2.1.
4. **Nativní aplikace:** C + Hildon (doporučeno), nebo Vala či Python?
5. Je pro tebe přípustný **dočasný kompromis**, že brána mluví s telefonem bez TLS 1.2 (jen LAN, HTTP/IMAP)?

## 9. Zdroje

- Indexy Fremantle repozitářů a zdrojové balíčky: [maemo.plan9.de](http://maemo.plan9.de/apt-mirror/mirror/repository.maemo.org/)
- [maemo-leste na GitHubu](https://github.com/maemo-leste) (Hildon, Modest, SyncEvolution, ...)
- [SyncEvolution pro Maemo 5/N900 (2010)](https://pohly.pages.freedesktop.org/syncevolution/blogs/pohly/2010/syncevolution-092-and-10-released/)
- [Syncevolution na N900 s CalDAV/CardDAV (Blaise Alleyne)](https://blaise.ca/blog/2013/04/27/howto-caldavcarddav-sync-from-n900-to-sogo-using-syncevolution/)
- [Maemo 5 Developer Guide: psaní aplikace](https://wiki.maemo.org/Documentation/Maemo_5_Developer_Guide/Application_Development/Writing_a_new_maemo_application)
- [Qt 4.7 na Maemo 5 (platform notes)](https://doc.qt.io/archives/qt-4.7/platform-notes-maemo5.html)
- [maemo.org wiki: Podcasts](http://wiki.maemo.org/Podcasts), [Email](https://wiki.maemo.org/Email), [N900 Resources](http://wiki.maemo.org/N900_Resources)
- [newsboat: CHANGELOG (požadavky na Rust)](https://github.com/newsboat/newsboat/blob/master/CHANGELOG.md)
