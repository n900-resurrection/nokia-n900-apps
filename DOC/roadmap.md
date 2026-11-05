# Plán: moderní TLS, e-mail, feedy a podcasty, rádio a audioknihy (Audiobookshelf) na N900

Stav k 2026-11-04. Rešerše a plán, nic z toho zatím není implementováno. Značení: **[ověřeno]** = zjištěno z indexů
repozitářů, zdrojů nebo přímo měřením (na telefonu nebo ze serveru); **[odhad]** = můj závěr bez zkoušky;
**[ověřit]** = je potřeba vyzkoušet. Související: [packaging.md](packaging.md), [mirror.md](mirror.md), [../TODO.md](../TODO.md).

## 0. Rozhodnutí (2026-11-04)

| Rozhodnutí | Důsledek |
|---|---|
| **Moderní TLS na telefonu je velká priorita** | Fáze 1. Všechno ostatní na ní stojí |
| **Kalendář a kontakty se zatím vypouštějí** | SyncEvolution, Radicale a CalDAV/CardDAV jsou mimo plán (zůstávají jen jako nápad do budoucna) |
| **Žádná „brána“ na domácím serveru, která věci předžvýká** | Vypouští se IMAP relay, podcast server a proxy rádií. Telefon musí umět bezpečné spojení **sám** |
| **Účty: Centrum a @tul.cz** | Konkrétní servery a nároky na TLS jsou v sekci 2 |
| **Přibývá Audiobookshelf** | Klient pro Audiobookshelf je ve fázi 4 |
| Terminálové nástroje všude, kde to jde, a GUI na slabém HW | Platí dál |

Omezení zařízení **[ověřeno]**: Cortex-A8 600 MHz, **245 MB RAM**, swap 786 MB, kořenový oddíl 62 MB volných, `/home` 1,1 GB
volných, Python 2.5.4, glibc 2.5, jádro 2.6.28, OpenSSL 0.9.8n, OpenSSH 5.1.

## 1. Cíle

(a) e-mail z `@centrum.cz` a `@tul.cz`, (b) feedy a podcasty, (c) internetové rádio, audioknihy a podcasty včetně
**Audiobookshelfu**, a to všechno **rozumně bezpečně přímo z telefonu**.

## 2. Stav TLS u poskytovatelů, které používáš [ověřeno měřením]

Test z mého počítače (OpenSSL 3, `@SECLEVEL=0`) a z telefonu (náš `curl` s mbedTLS, ověřování certifikátu zapnuté):

| Server | TLS 1.0 / 1.1 | TLS 1.2 | TLS 1.3 | Z telefonu naším `curl`em |
|---|---|---|---|---|
| `imap.centrum.cz:993` | **odmítá** | ano | ano | **TLS 1.3 OK**, certifikát ověřen |
| `smtp.centrum.cz:465` | **odmítá** | ano | ano | **TLS 1.3 OK**, certifikát ověřen |
| `mbox.tul.cz:993` (IMAP) | **odmítá** | ano | ne | **TLS 1.2 OK**, certifikát ověřen |
| `smtp.tul.cz:587` (STARTTLS) | **přijímá** (ECDHE-AES256-SHA) | ano | ano | z telefonu `Connection refused` (viz níže) |
| `smtp.tul.cz:465` | | | | z telefonu `Connection refused` |

- Se **systémovým OpenSSL telefonu** (0.9.8n, jen TLS 1.0) hlásí `imap.centrum.cz` hned `tlsv1 alert protocol version`.
  Staré aplikace se tedy ke Centrum ani k IMAPu TUL **nepřipojí**.
- **TUL nepoužívá Microsoft 365**: MX je `bubo.tul.cz` (záloha `tul.cesnet.cz`), vlastní servery. OAuth2 tedy
  pravděpodobně není potřeba, jen jméno a heslo **[odhad, ověřit u CIT TUL]**. Starší stránka
  [liane.tul.cz/en/e-mail](https://liane.tul.cz/en/e-mail) uvádí IMAP `mbox.tul.cz:993` a SMTP `smtp.tul.cz:587`.
- Centrum: IMAP `imap.centrum.cz:993`, SMTP `smtp.centrum.cz:465` (SSL) nebo `587` (STARTTLS), přihlášení celou adresou a
  heslem. O heslech aplikací jsem nenašel zmínku **[ověřit v nastavení účtu]**.
- **Upozornění:** `smtp.tul.cz` vrací z telefonu `Connection refused`, ačkoli z počítače předtím odpovídal. Zkoušel jsem ho
  v rychlém sledu (čtyři TLS handshaky z tvé IP), takže jsem ho **mohl dočasně zablokovat** (typicky fail2ban). **[odhad]**
  Dál ho zkoušet nebudu a před dalším pokusem ho zopakuj ručně, až uplyne čas nebo z jiné sítě.

## 3. Jak funguje TLS na telefonu a co z toho plyne [ověřeno na telefonu]

| Součást | Jaká TLS knihovna | Pozn. |
|---|---|---|
| **Modest** (systémový e-mail, 3.4.8) | **NSS** (`libssl3.so`, `libnss3.so` z balíčku `libnss3 20100401-1.9.2`, dodávaného s prohlížečem MicroB), přes `libcamel-lite-1.2` a `libtinymail-camel` | **Ne OpenSSL.** Oprava systémového OpenSSL Modestu nepomůže |
| MicroB (prohlížeč) | NSS | Komunita uvádí, že oprava OpenSSL nepomůže, je to jiná knihovna |
| `wget`, `libcurl3`, `openssl`, `ssh` | OpenSSL 0.9.8n (`libssl0.9.8`) | Oprava OpenSSL by pomohla těmto |
| **Náš `curl` 8.23 a `git` 2.56** | mbedTLS 3.6.7, **staticky** | TLS 1.2/1.3 funguje už dnes |

Cesty, jak dostat moderní TLS do aplikací:

| Cesta | Co to je | Hodnocení |
|---|---|---|
| **A. Nové vlastní programy se statickým TLS** (jako `curl`, `git`) | Pro každý program přeložit OpenSSL 3 nebo mbedTLS dovnitř | **Doporučeno.** Bezpečné, nezávislé na systému, ověřené postupem |
| **B. Přeložit znovu hotové GUI aplikace z Extras** (`claws-mail 3.7.3`, `alpine`, `mutt`) s novým TLS | Zdrojové balíčky jsou v mirroru | Dobré pro GUI e-mail (`claws-mail` v GTK je lehký). Pozor na `libetpan` (TLS vrstva Claws) |
| **C. Vyměnit NSS v systému** (nový `libnss3`/`libssl3`) | Jediná cesta, jak opravit **Modest** i MicroB najednou | **Velmi riziková** **[odhad]**: nové NSS potřebuje C++11 a sestavovací systém gyp/ninja; ABI musí sedět s Gecko 1.9.2 a camel-lite. Při chybě přestane fungovat prohlížeč i pošta. Odložit |
| **D. Přeložit znovu `libcamel-lite`/`libtinymail-camel` (Modest) s OpenSSL** | Modest by mluvil moderním TLS | Zdrojáky Modestu a camel-lite: `github.com/maemo-leste/modest` (větev `PR1.3`), ale Leste je port na novější Debian. Obtížné, **[ověřit]** proveditelnost až po A a B |
| **E. Opravit systémový OpenSSL** (drop-in `libssl.so.0.9.8`) | Pomůže `wget`, `ssh`, `openssl` | Komunitní postup existuje (CSSU-devel, OpenSSL 1.1.0h z Debianu přeložený pro Fremantle a hostovaný v repozitáři CSSU) **[ověřeno z diskuse, neověřeno na zařízení]**. Zachraňuje jen programy s OpenSSL |

**Závěr:** cesta **A** pro nové nástroje (rychlé a bezpečné) a **B** pro GUI pošty. Modest (cesta D nebo C) je volitelný
cíl až po fázi 2. Dlouhodobě stojí za průzkum E jako bonus.

## 4. Co už existuje [ověřeno z indexů Fremantle repozitářů]

Zdroj: `extras`, `extras-testing`, `extras-devel` na `maemo.plan9.de`. Zdrojové balíčky jsou u všech v
`dists/fremantle/free/source/Sources.gz` (v `extras` 2 054), takže kód lze přečíst a přeložit znovu.

| Oblast | Terminálové | GUI | Poznámka |
|---|---|---|---|
| **E-mail** | `mutt 1.5.20`, `alpine 2.00`, `offlineimap 6.2.1` | Modest 3.4.8 (systém), **`claws-mail 3.7.3`** | Všechno na starém TLS. `msmtp`, `isync`, `neomutt` v repu nejsou |
| **Feedy a podcasty** | **nic terminálového** | `gpodder 2.20.2`, `feedingit 0.9.1`, `feedcircuit`, `cutenews` | |
| **Rádio a audioknihy** | `cmus 2.4.0`, `mpg123 1.12.1`, `mpc`, `ncmpc`, `mplayer` | Media Player (MAFW), `internetradioplayer`, `msoma`, `mediabox`, **`panucci 0.99.3`**, `nqaap` | `ogg-support` rozšiřuje GStreamer; `mpd`, `vlc` chybí |
| **Jazyky** | | `python3 3.4.0`, `python-hildon 0.9.0` | Python 3.4 je v Extras |

Na telefonu **[ověřeno]**: PulseAudio 0.9.15 (Nokia moduly), GStreamer 0.10 (včetně `ffmpeg`), `gst-launch-0.10`, `aplay`, `paplay`,
ALSA, `libhildon1 2.2.23`, GTK 2.14.7. **Chybí `jq`** a jakýkoli JSON nástroj (Python 2.5 nemá modul `json`).

### Zdrojové kódy

| Zdroj | Co v něm je |
|---|---|
| Mirror Extras: `pool/fremantle/free/source/<písmeno>/<balíček>` | gpodder (2.3, 2.20), panucci, claws-mail, alpine, cmus, mediabox, nqaap a stovky dalších |
| GitHub `maemo-leste/*` | Hildon a systém: `libhildon`, `hildon-desktop`, `hildon-application-manager`, `modest` (větev `PR1.3`), `calendar-backend`, `libconic`, `connui-*` |
| GitHub `gpodder/gpodder` | Aktuální gPodder. Maemo 5 verze 2.x je v Extras zdrojích |
| maemo.org wiki *Maemo 5 Developer Guide* | Dokumentace vývoje aplikací |

`thp/gpodder` a `thp/panucci` na GitHubu **neexistují**; Fremantle verze jsou ve zdrojových balíčcích v mirroru.

## 5. Audiobookshelf [ověřeno z dokumentace API]

[Audiobookshelf](https://www.audiobookshelf.org) je hostovaný server (vlastní nebo tvůj) s REST API. Z [API dokumentace](https://api.audiobookshelf.org):

| Co | Endpoint |
|---|---|
| Přihlášení | `POST /login` s `{"username","password"}`, token v `user.token`. Poté hlavička `Authorization: Bearer <token>`; u GET lze i `?token=<token>` |
| Kontrola tokenu | `GET /api/authorize` |
| Knihovny | `GET /api/libraries` |
| Položky | `GET /api/libraries/<id>/items` (řazení, filtr, stránkování), `GET /api/items/<id>?expanded=1&include=progress` |
| Přehrání | `POST /api/items/<id>/play` (tělo: `forceDirectPlay`, `supportedMimeTypes`, …) vrací **session** s `audioTracks[]` (`contentUrl`, `duration`, `startOffset`, `mimeType`) |
| Proud souboru | `contentUrl` ve tvaru `/s/item/<libraryItemId>/<soubor>` (přidat token) |
| Obálka | `GET /api/items/<id>/cover` |
| Stav | `GET /status`, `GET /ping`, `GET /healthcheck` |
| RSS | otevření RSS feedu položky, kolekce nebo série (cesta nezjištěna) |

**Nezjištěno** (části dokumentace jsem nedočetl): cesty pro **synchronizaci a zavření session** a **uložení postupu** (`POST /api/session/<id>/sync`,
`…/close`, `PATCH /api/me/progress/<id>` jsou moje odhady podle známého API, **[ověřit proti tvému serveru]**).

### Návrh klienta

1. **Přihlášení a token** přes náš `curl` (TLS 1.2/1.3), token uložit s právy 600.
2. **JSON:** na telefonu není `jq` ani Python `json`. Řešení: přeložit **`jq`** staticky (C, jedna binárka) **[odhad]**,
   nebo napsat klienta rovnou v C s malým parserem (cJSON/jsmn).
3. **Přehrávání:** potíž je formát. Audioknihy bývají **MP3** (zvládne `mpg123`) nebo **M4B/AAC** (kontejner MP4, `moov` často
   na konci souboru, vyžaduje seekování). Z roury (`curl … | přehrávač`) se MP4 hrát nedá. Možnosti:
   a) stáhnout soubor/kapitolu na `/home` a hrát lokálně (`gst-launch`/`mplayer`/`panucci`, GStreamer na telefonu AAC umí),
   b) vynutit od serveru MP3 (`supportedMimeTypes`; ABS pro nepodporované formáty transkóduje do HLS, který GStreamer 0.10 nepřehraje),
   c) HTTP Range přes `curl` do souboru, který přehrávač čte. **[ověřit na konkrétní knize z tvého serveru]**
4. **Postup:** po zavření session poslat `currentTime` zpět serveru, aby se postup shodoval s mobilní aplikací.
5. **GUI:** existující **Panucci** a **nqaap** umí lokální soubory a pamatují pozici, stačí je krmit staženými kapitolami. Vlastní
   Hildon aplikace s napojením na Audiobookshelf je cíl fáze 5.

Co potřebuju vědět: **kde Audiobookshelf běží** (adresa, HTTPS?, vlastní certifikát?), v jakých formátech máš knihy a zda je
server dostupný z mobilní sítě, nebo jen doma. Bez přihlašovacích údajů nic zkoušet nemůžu.

## 6. Terminálové nástroje: výběr a proveditelnost

Společný základ je **moderní TLS knihovna** (fáze 1).

### E-mail

| Nástroj | TLS | Verdikt |
|---|---|---|
| **mutt 2.x** | OpenSSL nebo GnuTLS; IMAP i SMTP má v sobě | **Doporučeno.** Jedna binárka, žádný externí fetcher. Nutné OpenSSL 3 staticky |
| **claws-mail 3.7.3** (GUI, GTK) | přes `libetpan` (OpenSSL) | **GUI cesta (B):** přeložit znovu s novým TLS, zdroj je v mirroru |
| alpine 2.00 | OpenSSL (staré) | Je v repu, stačí přeložit znovu |
| neomutt | OpenSSL/GnuTLS | Podobné jako mutt, víc závislostí **[odhad]** |
| aerc | Go | **Ne** (Go dnes vyžaduje novější jádro) **[odhad]** |
| msmtp, isync | OpenSSL/GnuTLS | Jen pokud mutt nestačí |
| **curl s IMAP/SMTP** | mbedTLS (máme) | **Rychlý bonus:** náš `curl` jsem sestavil s `--disable-imap --disable-smtp`. Zapnout je stojí pár kB a umožní skripty (`curl imaps://…`) |

Heslo: Centrum i TUL používají **jméno a heslo**. Telefon **nešifruje úložiště**, takže ukládání hesla do souboru je riziko.
Doporučení: soubor s právy 600 jen pokud je to heslo aplikace/jednorázové, jinak se na heslo ptát při startu (mutt to umí).
Heslo ke škole (TUL) je pravděpodobně totéž jako k univerzitním systémům, proto bych ho do souboru **nedával**.

### Feedy a podcasty

| Nástroj | Verdikt |
|---|---|
| **sfeed** (+ `sfeed_curses`) | **Doporučeno.** Malé C programy bez závislostí kromě libc a ncurses; feed stahuje náš `curl` **[odhad, ověřit]** |
| newsboat | Vyžaduje **Rust** (aktuálně ≥ 1.90) **[ověřeno z changelogu]**, cross-překlad pro armv7 s jádrem 2.6.28 je nerealistický |
| podcasty | `sfeed` + `curl` (přílohy) + `mpg123`/`cmus`; shell skript pro frontu a pozici |

### Rádio a audioknihy

| Nástroj | Verdikt |
|---|---|
| **mpg123** (nový) | HTTPS rádio: `curl -s URL \| mpg123 -`. Výstup přes PulseAudio **[ověřit]** |
| **cmus** (2.4 → 2.12) | Konzolový přehrávač s knihovnou, v repu 2.4.0 |
| GStreamer | Už na telefonu: `gst-launch-0.10 fdsrc ! decodebin ! pulsesink` za `curl`em, dekodéry od Nokie (AAC, WMA) **[ověřit]** |
| mpd + ncmpc | Pro telefon zbytečně těžké **[odhad]** |

## 7. Nativní aplikace s Hildonem

| Volba | Pro | Proti |
|---|---|---|
| **C + GTK 2.14 + Hildon (`libhildon-1` 2.2)** | Nejmenší, nejrychlejší, `-dev` balíčky v sysrootu (`libhildon1-dev`, `libgtk2.0-dev`) | Ruční správa paměti |
| Vala → C | Příjemnější psaní | Potřeba Vala a vapi pro `hildon-1` **[ověřit]** |
| Python 2.5 + `python-hildon` | Rychlý vývoj | Python 2.5 je mrtvý, vyšší paměť, TLS 1.0 |
| Qt 4.7 (Maemo 5) | QtMobility, moderní API | Těžší za běhu; Qt jsem v Extras indexu nenašel **[ověřit]** |

**Doporučení:** C + GTK2 + Hildon. TLS řeší statické `libcurl` z našeho buildu (`apps/curl`), takže se aplikace připojí sama.

Vývojová smyčka ve Workshopu **[ověřit]**: překlad našim `maemo-gcc` proti sysrootu (`PKG_CONFIG_SYSROOT_DIR`), zkouška v
**Xephyr + qemu-user**, balení `scripts/debpack.sh`.

## 8. Plán po fázích

Odhad práce: **S** = hodiny, **M** = den, **L** = několik dní. **[odhad]**

### Fáze 1: moderní TLS (priorita)

| # | Úkol | Práce | Výsledek |
|---|---|---|---|
| 1.1 | **OpenSSL 3.x staticky** jako znovupoužitelná závislost (`build/deps/openssl-*`), cross-překlad s `maemo-gcc` | M | Základ pro mutt, alpine, claws, ssh |
| 1.2 | **curl: zapnout IMAP/SMTP/POP3** a znovu sestavit | S | `curl imaps://…` na telefonu, rychlý test obou účtů |
| 1.3 | **CA balík:** pravidelná aktualizace (skript + `curl`), uložení na jednom místě | S | `cacert.pem` se dá obnovit jedním příkazem |
| 1.4 | **Test obou účtů** přes `curl` (TLS, certifikát, přihlášení): Centrum a TUL | S | Jistota, že spojení z telefonu funguje (bez ukládání hesel) |
| 1.5 | **Průzkum systémového TLS:** Modest přes NSS (varianty C/D), systémový OpenSSL (varianta E), co dělá CSSU-devel | M | Rozhodnutí, zda stojí za to |

### Fáze 2: e-mail z telefonu

| # | Úkol | Práce |
|---|---|---|
| 2.1 | **mutt 2.x** s OpenSSL staticky, šablony nastavení pro Centrum a TUL | M |
| 2.2 | **claws-mail** znovu s novým TLS (GUI), závislosti `libetpan` atd. | L |
| 2.3 | alpine znovu přeložený | S až M |
| 2.4 | (volitelně) Modest přes camel-lite s OpenSSL | L |

### Fáze 3: feedy a podcasty

| # | Úkol | Práce |
|---|---|---|
| 3.1 | **sfeed** + shell skript pro podcasty (stahování příloh, fronta) | S |
| 3.2 | Rozhodnout o gPodderu 2.20 (v repu, jen starý TLS) | S |

### Fáze 4: audio, audioknihy a Audiobookshelf

| # | Úkol | Práce |
|---|---|---|
| 4.1 | **mpg123** a **cmus** nové, ověřit výstup přes PulseAudio a rádia přes HTTPS | S až M |
| 4.2 | **jq** staticky (nebo parser v C) | S |
| 4.3 | **Audiobookshelf klient (terminál):** přihlášení, seznam knih, stažení a přehrání, uložení postupu. Nejdřív zjistit formát tvých knih | M až L |
| 4.4 | Napojení na **Panucci**/**nqaap** (stažené kapitoly) | S |

### Fáze 5: vlastní nativní aplikace v Hildonu

| # | Úkol | Práce |
|---|---|---|
| 5.1 | „Hello Hildon“ v `apps/`, překlad proti sysrootu, zkouška v Xephyr + qemu, balíček s ikonou | M |
| 5.2 | **Audiobookshelf klient s Hildon GUI** (seznam knih, přehrávání přes GStreamer, synchronizace postupu) | L |
| 5.3 | (volitelně) čtečka feedů nad `sfeed` | L |

### Zásady napříč fázemi

- **Bezpečnost:** ověřování certifikátů vždy zapnuté, CA balík z balíčku `curl`. Telefon nemá šifrování úložiště a běží na něm zastaralé
  jádro: ber ho jako **nedůvěryhodné zařízení**, minimalizuj uložená hesla (hesla aplikací, tokeny s omezenou platností).
- Každá aplikace v `apps/<app>/` s `mk/app.mk`, balíček přes `scripts/debpack.sh`, ověření na telefonu a `<app>.md`.
- **Nic se neinstaluje bez tvého svolení** a vždy se zapíše, jak se vrátit.

## 9. Otevřené otázky

1. **Audiobookshelf:** adresa serveru, HTTPS/certifikát, formáty knih, dostupnost mimo domov.
2. **TUL:** je přihlášení opravdu jen jménem a heslem (žádné OAuth, žádné dvoufaktorové)? Je `smtp.tul.cz` dostupný z tvé sítě?
3. **Centrum:** podporuje hesla aplikací?
4. **Pořadí uvnitř fáze 2:** terminálový mutt, nebo GUI Claws Mail jako první?
5. **Modest:** stojí za pokus (varianty C/D), nebo ho zatím vzdáváme?

## 10. Zdroje

- Indexy Fremantle repozitářů a zdrojové balíčky: [maemo.plan9.de](http://maemo.plan9.de/apt-mirror/mirror/repository.maemo.org/)
- [Audiobookshelf API](https://api.audiobookshelf.org), [Audiobookshelf](https://www.audiobookshelf.org)
- [Centrum.cz IMAP/SMTP (Mailbird)](https://www.getmailbird.com/setup/access-centrum-cz-via-imap-smtp), [TUL e-mail (LIANE)](https://liane.tul.cz/en/e-mail)
- [Resurrect a Nokia N900 (TLS)](https://dt.iki.fi/nokia-n900-resurrect), [Idea: N900 security update (openssl, browser) – talk.maemo.org](http://talk.maemo.com/showthread.php?t=96106&page=6),
  [QT and OpenSSL 1.1.0h](https://talk.maemo.org/showthread.php?t=100352), [Full guide to stock S/W on N900 that is using OpenSSL](https://talk.maemo.org/showthread.php?t=96288)
- [maemo-leste na GitHubu](https://github.com/maemo-leste)
- [Maemo 5 Developer Guide: psaní aplikace](https://wiki.maemo.org/Documentation/Maemo_5_Developer_Guide/Application_Development/Writing_a_new_maemo_application)
- [Qt 4.7 na Maemo 5](https://doc.qt.io/archives/qt-4.7/platform-notes-maemo5.html)
- [newsboat CHANGELOG (Rust)](https://github.com/newsboat/newsboat/blob/master/CHANGELOG.md)

## 11. Upřesnění zadání (2026-11-05)

- **Audiobookshelf** běží jen v LAN bez TLS: `http://192.168.1.101:13378` (kontejner na docker-runner, `GET /ping` vrací `{"success":true}`). Úvodní stránka s odkazy je `http://192.168.1.101:3000/`. Zatím jen jako **zdroj**: stáhnout epizody/knihy na N900 a přehrát lokálně (mpg123/cmus/nativní přehrávač). Bez synchronizace postupu. Plain HTTP v LAN tedy stačí a TLS není pro ABS blokující. Pro testy přihlášení bude potřeba účet; nic se nemaže ani nemění (jen čtení).
- **Podcasty:** uživatelův postmarketOS postup používá `gpodder-adaptive` a příkaz `gpo` (poznámky `doc/pmos_podcasts.md` v nokia-n900-notes). Je to Python 3 (gPodder 3.11: podcastparser, mygpoclient, requests), takže přenos vyžaduje Python 3 + knihovny na Maemo 5. Alternativy: gPodder 2.20.2 z repozitáře Fremantle (Python 2, má GUI), nebo `sfeed` + curl skript (malý, bez Pythonu). Doporučení: začít `sfeed` + skript, `gpo` až bude hotový vlastní Python 3.
- **E-mail v GUI.** První účet Centrum. **TUL odloženo** (kvůli možnému banu `smtp.tul.cz`, nezkoušet).
- **Claws Mail** je na 800x480 příliš velký → zvážit nativní Modest (viz DOC/roadmap sekce 3, zdroje maemo-leste/modest, tinymail, camel-lite) a jeho TLS problém (NSS).
- **Mutt** přidán do TODO: nativní binárka s OpenSSL 3 statickou; nad ním případně jednoduchý Hildon frontend, který volá příkazy terminálové utility.

### Stav fáze 1 (2026-11-05)
- 1.1 hotovo: statický OpenSSL 3.5.9 (apps/openssl, build/deps/openssl-3.5.9/lib). Zatím jen přeložen, ještě na zařízení nevyzkoušen žádný program, který ho linkuje.
- 1.2 hotovo: curl 8.23.0 s imap/imaps/smtp/smtps/pop3/pop3s. Na telefonu ověřeno TLS spojení a pozdrav serveru bez přihlášení: `imaps://imap.centrum.cz` ("BalaIMAP server ready") a `smtps://smtp.centrum.cz:465` (220). Přihlášení ještě nezkoušeno, balíček .deb nepřebalen ani neinstalován (testovací binárka je v /home/user/apps/curl-mail-test).
