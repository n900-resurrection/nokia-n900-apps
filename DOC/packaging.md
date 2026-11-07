# Balíčky pro Maemo 5: struktura repa, závislosti, .deb a hostování

Stav k 2026-11-04. Obecný kontext je v [../README.md](../README.md). Návrh, ne hotová implementace,
pokud není řečeno jinak. Co je ověřené, je označeno **ověřeno**.

## 1. Zjištění z prvního reálného backportu (WordGrinder 0.8)

**Ověřeno:** [../apps/wordgrinder/build.sh](../apps/wordgrinder/build.sh) postaví WordGrinder 0.8 od nuly,
binárka (681 kB po stripu) běží na N900 (`--help`, převod txt → html). Co bylo potřeba:

| Problém | Řešení |
|---|---|
| Upstream `Makefile` staví pomocnou Lua cílovým `$(CC)` | hostitelská Lua zvlášť, předaná přes `LUA_INTERPRETER` |
| `symbol stat64 is already defined` (hlavičky glibc 2.5 + gnu99) | `-fgnu89-inline` ve wrapperu `scripts/maemo-gcc` |
| `get_wch` nenalezeno | širokoznaková hlavička je v `usr/include/ncursesw/` |
| `cannot open libm.so` | absolutní symlinky ve sysrootu → `fetch_sysroot.py` je přepíše na relativní |
| `strip: Unable to recognise the format` | `WANT_STRIPPED_BINARIES=no`, strip přes `arm-linux-gnueabi-strip` |
| **Telefon nemá `libncursesw.so.5`** (jen libc, libm, libz) | ncursesw **staticky** (`libncursesw.a` je v sysrootu) |

Poučení: sysroot (Fremantle SDK) neznamená, že tytéž knihovny jsou na zařízení. SDK je vývojová sada,
telefon má jen běhové knihovny, a z nich ne všechny.

## 2. Návrh struktury repozitáře

```
N900/
├── apps/<aplikace>/       # jedna složka = jedna aplikace
│   ├── build.sh           # sestavení (upstream tag, vlastní kroky) – spouští se ve Workshopu
│   ├── patches/           # záplaty proti upstreamu (pokud jsou)
│   ├── debian/            # metadata pro .deb (control, postinst, ikona…) – později
│   └── README.md          # co to je, verze, co se muselo řešit
├── src/                   # vlastní zdrojáky podle jazyka: c/, go/, python3/, rust/ (hello.c ve c/hello)
├── scripts/               # společné: maemo-gcc, fetch_sysroot.py, (později) mkdeb.sh
├── DOC/                   # poznámky a rozbory
├── repo/                  # APT repozitář pro naše balíčky (v .gitignore, generované)
├── build/                 # upstream zdrojáky, objekty, výstupy (v .gitignore)
└── sysroot/ downloads/    # obnovitelné skriptem (v .gitignore)
```

- Upstream zdrojáky **nekopírovat do repa**: `build.sh` je stáhne podle tagu. Do gitu patří jen
  `build.sh` a `patches/`. Je to malé a dohledatelné.
- Verze balíčku = verze upstreamu + náš suffix, např. `0.8-1maemo1` (aby se rozlišily od případných
  balíčků z Extras).
- Společné (flagy kompilátoru, sysroot) jen v `scripts/`, ne v každé aplikaci zvlášť.
- Dokud je repo bez gitu, strukturu lze měnit zdarma. Doporučuju `git init` před dalšími aplikacemi.

## 3. Na čem si můžeme dovolit záviset (sdílené knihovny)

Pravidlo: **závislost na systému jen tam, kde je knihovna součástí Maemo 5 a nemění se.**
Všechno ostatní do binárky nebo do soukromé složky aplikace.

| Kategorie | Příklad | Přístup |
|---|---|---|
| Základ systému | `libc6` (2.5), `libm`, `libpthread`, `libdl` | závislost, ale **nejvyšší symbol `GLIBC_2.4`/2.5** hlídat skriptem |
| Běžně přítomné knihovny | `libz1`, `libssl0.9.8`, GTK2/Hildon/glib na zařízeních s UI | závislost, **ověřit na telefonu** (`ldd`, `dpkg -l`) |
| Chybí na zařízení | `libncursesw5` | statické linkování (`-Bstatic`), jako u WordGrinderu |
| Novější než systém | OpenSSL ≥ 1.1, novější libstdc++ | staticky, nebo soukromá kopie v `/opt/<app>/lib` s `RPATH=$ORIGIN/../lib` |
| Knihovny vlastní aplikace | Lua, minizip… | přibalené upstreamem, nic nedělat |

Co je skutečně nainstalované na testovacím N900 (`dpkg -l`, ověřeno 2026-11-04): `libc6 2.5.1`,
`libstdc++6 4.2.1`, `libssl0.9.8 0.9.8n`, `libncurses5 5.7` (**bez w**), `libgtk2.0-0 2.14.7`, `libhildon1 2.2.23`,
`libsdl1.2 1.2.13` (+ image, mixer), `libzip1`, `libzbar0`; zlib je k dispozici jako `libz.so.1`.

### ncurses: statická knihovna, nebo závislost? (rozhodnuto 2026-11-04)

Telefon má jen `libncurses5` 5.7 (**bez** širokých znaků); `libncursesw` na něm není. SDK ji má (297 kB sdílená,
487 kB statická), stejné verze 5.7. Naměřené dopady (po stripu):

| Program | Potřebuje | Zvolené řešení | Velikost binárky |
|---|---|---|---|
| tty-clock, cmatrix | obyčejný ncurses | **dynamicky, `Depends: libncurses5 (>= 5.7)`** (systémová) | 18 kB, 14 kB |
| cbonsai | široké znaky (`cchar_t`) | **staticky** ncursesw + panelw | 156 kB |
| WordGrinder | široké znaky | **staticky** ncursesw | 681 kB (z toho asi 150 kB ncursesw) |
| htop 3 | široké znaky (Unicode) | **staticky** ncursesw | 394 kB |

Pravidlo:
1. Stačí-li obyčejný ncurses, **závislost na systémovém `libncurses5`**: je na každém telefonu, nic se
   nehostuje a binárka je malá.
2. Jsou-li potřeba široké znaky, **statický ncursesw** v binárce. Cena je asi 150 kB na program.

Proč ne sdílený balíček `libncursesw5`: ušetřil by asi 150 kB × 4 programy ≈ 0,6 MB, ale vyžadoval by v našem
repozitáři další balíček (přebraný z SDK repa, ncurses má volnou licenci), pořadí instalace a hlídání verzí.
Při velikosti úložiště (1,2 GB volných na `/home`) to nestojí za složitost. Vrátit se k tomu má smysl, až
bude vlastní repozitář a aplikací s ncursesw bude víc (řádově 10 a více).

Doporučení:
- **Nikdy nenahrazovat systémové knihovny** (`libc`, `libstdc++6`, `libssl0.9.8`). Rozbilo by to Maemo.
- Preferovat **statické linkování** pro cokoli, co není na zařízení garantované. Cena je velikost
  (WordGrinder: +150 kB za ncursesw), přínos je žádné závislosti v `Depends`.
- Soukromé sdílené knihovny jen když jich je víc aplikací, jinak statika.
- Aplikace instalovat do **`/opt/<app>`**. Na telefonu je `/opt` bind mount z `/home/opt` (ext3, ~1,3 GB
  volných), kdežto kořenový oddíl je malý. **Ověřeno** (`mount`, `df`). Do `/usr` jen malé wrappery/odkazy.
- C++: Ubuntu libstdc++ staticky (`-static-libstdc++ -static-libgcc`), systémová je 4.2.1. **Ověřit.**
- Kontrola v CI/skriptu: `readelf -d` (jen `NEEDED` z whitelistu) a `objdump -T | grep GLIBC` (max 2.5).

## 4. Z binárky na .deb

**Neověřeno, návrh.** Balíček `armel`, `Architecture: armel`.

```
Package: wordgrinder
Version: 0.8-1maemo1
Architecture: armel
Section: user/office           # Maemo 5: sekce "user/<kategorie>" pro Application Manager
Depends: libc6 (>= 2.5), zlib1g
Maintainer: …
Description: Console word processor
 …
```

- Maemo 5 Application Manager chce v `control` sekci `user/…` a pro ikonu/zobrazované jméno pole
  `XB-Maemo-Display-Name`, `XB-Maemo-Icon-26` (base64). **[ověřit]** v dokumentaci Maemo 5 packaging.
- Obsah: `/opt/wordgrinder/bin/wordgrinder`, symlink `/usr/bin/wordgrinder` (v `postinst`), `.desktop`
  do `/usr/share/applications/hildon/` pro terminálovou aplikaci s `exec` přes `osso-xterm`. **[ověřit]**
- Balení: `dpkg-deb --build` v Workshopu (dpkg-dev tam je). Pak `lintian` je nad rámec, Maemo má své požadavky.
- Instalace/odinstalace vyzkoušet na telefonu před hostováním (`dpkg -i`, `dpkg -r`, `dpkg -P`).

## 5. Lokální repozitář na Proxmoxu

Návrh (plán, nic z toho se zatím nestavělo):

- LXC kontejner (Debian) na Zalmanu: **nginx** (HTTP, jen LAN) + **reprepro** nebo **aptly** pro
  vlastní balíčky.
- Dvě oddělené části:
  1. **Kopie `maemo.plan9.de`** (`extras`, `extras-testing`, `extras-devel`, `sdk`): stahuje se jednorázově
     a pak jen aktualizuje, viz [mirror.md](mirror.md).
  2. **Vlastní repo `n900dev`**: `dists/fremantle/free/binary-armel/` + `pool/`. Na telefonu se přidá
     jako další katalog (`deb http://<server>/n900dev/ fremantle free`).
- **Doporučuji vlastní repo jako samostatný katalog**, ne přimíchávat balíčky do kopie. Kopie zůstane
  čistá (jde ji kdykoli obnovit z originálu) a naše balíčky se nepřepíšou při synchronizaci. Přimíchání
  do `extras-devel` jde, ale stojí to složitější správu (generování `Packages` nad cizím stromem).
- Podpis: vlastní GPG klíč, `Release.gpg`. Apt na telefonu (0.7.20.2maemo13.1) má metody `http`, `https`,
  `gpgv`, `ssh`. Jak se starý Application Manager chová k nepodepsanému repu, **neověřeno**.
  Do testů zařadit i variantu bez podpisu. Pro `apt-get` na telefonu fungovalo `[trusted=yes]` u novějších apt,
  tady **nejspíš ne** (apt 0.7.20).
- Hodiny: telefon měl při mém testu datum **1. 1. 2009**. `Release` s `Date:` v budoucnosti apt neřeší,
  ale nastavené hodiny potřebuje HTTPS a obecně pořádek. Řešit mimo balíčky.

## 6. Hostování balíčků na GitHubu: realizovatelnost

**Ověřeno na telefonu (2026-11-04):** `wget https://github.com` skončí
`SSL23_GET_SERVER_HELLO: tlsv1 alert protocol version`, `raw.githubusercontent.com` stejně
(`unknown protocol`). N900 má **OpenSSL 0.9.8n** (jen SSL/TLS 1.0), GitHub vyžaduje TLS 1.2+.
Přitom `apt` na telefonu metodu `https` má, ale použít ji proti GitHubu nelze.

| Co | Použitelné přímo z telefonu? | Poznámka |
|---|---|---|
| GitHub Pages jako APT repo | **ne** | jen HTTPS (u `*.github.io` nejde vypnout) |
| `raw.githubusercontent.com` | **ne** | jen HTTPS |
| GitHub Releases (assety) | **ne** | jen HTTPS |
| zdrojáky, issues, historie | ano, ale z počítače | normální použití |
| **GitHub Actions** (CI) | ano, jako stavitel | pozor, potřebuje Workshop-like prostředí, viz níže |

Realisticky:
- GitHub **ano** jako úložiště zdrojáků, `build.sh`, záplat, dokumentace, případně **archiv sestavených
  `.deb` v Releases** (limit asi 2 GB na soubor) jako záloha.
- GitHub **ne** jako server, ze kterého instaluje telefon. Telefon musí číst z **HTTP** zdroje na LAN
  (tvůj Proxmox) nebo z něčeho s HTTP (VPS s nginx). Vlastní server to řeší a je v souladu s tím,
  že repo nemá být veřejné.
- Pipeline: `git push` → (volitelně GitHub Actions postaví `.deb`) → pull na lokální server →
  `reprepro includedeb` → telefon `apt-get update`. První verze může být bez Actions: build ve Workshopu,
  `make deb`, `make publish` (scp na server).
- Licence: balíček s GPL softwarem vyžaduje nabídnout zdrojáky (stačí odkaz na upstream tag + naše
  záplaty). WordGrinder je MIT (+ přibalené komponenty pod BSD/MIT), tam stačí zachovat licenční texty.
  Pokud repo zůstane soukromé a na LAN, je to bezpředmětné, pro veřejné publikování ne.
- Alternativa pro veřejnost: HTTP-only zrcadlo na vlastní doméně (podobně jako to dělají
  `maemo.viniciuspaes.com` a `n900.h4ck1ng.me`). Jejich provoz je dobrovolnický, nezatěžovat je.

## 7. Návrh dalších kroků

1. Rozhodnout strukturu (sekce 2) a udělat `git init`.
2. `make deb` pro WordGrinder a zkouška instalace/odinstalace na N900 (zjistí hlavně požadavky Application Manageru).
3. LXC na Proxmoxu: nginx + reprepro, naimportovat WordGrinder, přidat katalog v telefonu.
4. Teprve potom kopie plan9 mirroru (disk, čas).
5. Další aplikace do `apps/`, každá s vlastním `build.sh` a README.

## 8. Otevřené otázky

- Maemo 5 packaging: přesná pole `control` pro Application Manager, ikona, `.desktop` pro terminálové aplikace.
- Chování starého apt/Application Manageru k nepodepsanému nebo samopodepsanému repu.
- Které knihovny jsou skutečně na zařízení (`dpkg -l` na telefonu) a tedy co lze dát do `Depends`.
- Hodiny na telefonu: nastavit a udržet (baterie RTC?).
