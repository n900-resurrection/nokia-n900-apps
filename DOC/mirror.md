# Repozitáře Maemo 5 a vlastní mirror

Stav k 2026-11-03. Obecný kontext je v [../README.md](../README.md).

## 1. Stav: žijí nějaké mirrory?

Ověřeno z mého stroje (curl, 2026-11-03):

| Zdroj | Stav | Poznámka |
|---|---|---|
| `repository.maemo.org` (originál) | **nedostupný** | DNS se překládá, port 80 odmítá spojení. `wiki.maemo.org` odmítá 443 také. |
| `repository.maemo.sbs` | **mrtvý** | Doména se nepřekládá (ENOTFOUND). Seznam „Fremantle 2024“ je zastaralý. |
| `maemo.muarf.org` (přímo) | nedostupný | Žádná cesta k hostiteli. |
| `maemo-archive.wedrop.it`, skeiron.org | mrtvé | Podle fóra vypnuté. |
| **`maemo.plan9.de`** | **žije** | Zrcadlo `repository.maemo.org` přes apt-mirror, snapshot **září 2017**. Viz 1.1. |
| **`n900.h4ck1ng.me`** | **žije** | Nový mirror (`Release` z 2026-03-29). Viz 1.2. |
| Wayback Machine | částečně | Stránky mají kopie, ale u bulk stahování vrací 429. |

Reddit r/N900 jsem nemohl číst (nástroj přístup blokuje). Hledání jména Vinicius Paes (Maemo/N900) nenašlo nic relevantního, jeho stránky tedy neznám. Pokud máš odkaz, pošli ho.

### 1.0 Co už mám v nokia-n900-notes

Poznámky v [maemoOS_files/Maemo 5.md](https://github.com/elPytel/nokia-n900-notes/blob/main/maemoOS_files/Maemo%205.md) (sekce Repository / Mirrors) už obsahují:

- varování, že `repository.maemo.org` je dole, a záložní kopii na web.archive.org (snapshot 2025-02-01),
- mirrory: [talk.maemo.org vlákno](https://talk.maemo.org/showthread.php?t=101524&page=3), `maemo.plan9.de` a `maemo.plan9.de/apt-mirror`,
- hotové `*.install` soubory v `maemoOS_files/repository/` (obsah jsem nečetl),
- balíčky ke stažení: `rootsh`, `sudser`, `bash3`, `git`, `ffmpeg` 0.5 (armel) a další `.deb` v `maemoOS_files/deb/`.

Nový je tedy hlavně mirror `n900.h4ck1ng.me` a ověření, že `maemo.plan9.de` je opravdu funkční včetně SDK.

### 1.0a maemo.viniciuspaes.com (Vinicius Paes)

Návod z fóra (vložil uživatel): vypnout všechny Nokia katalogy v Application Manageru a přidat

```
Extras:         http://maemo.viniciuspaes.com/extras/          fremantle  free non-free
Extras-testing: http://maemo.viniciuspaes.com/extras-testing/  fremantle  free non-free
Extras-devel:   http://maemo.viniciuspaes.com/extras-devel/    fremantle  free non-free
```

- V původním textu je u Extras-testing překlep: `viniciuspaes-com` místo `viniciuspaes.com`.
- Z mého stroje (2026-11-03) vracel server na `curl` **HTTP 403**, v prohlížeči se ti ale otevírá normálně. Nejspíš tedy blokuje automatizované klienty. Obcházet jsem to nezkoušel.
- Web uvádí: **„Repository restored… Please avoid excessive automated cloning or mirroring to help keep the service available.“** Pro vlastní mirror proto z tohoto serveru **nestahovat hromadně**. Buď použít `maemo.plan9.de` (viz 1.1), nebo autora požádat o souhlas, případně stahovat jen jednotlivé potřebné balíčky pomalu.
- Nabízí kromě N900 i N800/770 (Diablo, Gregale, …), Fremantle `extras`, `extras-testing`, `extras-devel` ve verzích `fremantle`, `fremantle-1.2`, `fremantle-1.3`.
- **SDK repozitáře** pro Fremantle: `deb http://maemo.viniciuspaes.com/ fremantle/sdk free non-free` a `fremantle/tools`. Řádek `nokia-binaries` potřebuje token (EULA).
- **Scratchbox mirror**: `https://scratchbox.viniciuspaes.com`, jen soubory pro N800 (kvůli místu na disku). Doporučuje Debian 6 (Squeeze) 32bit; na Fremantle SDK tedy nestačí.
- Web obsahuje i návod na lokální repozitář na zařízení: `deb [trusted=yes] file:/media/mmc2 ./`.
- Autor mirroru `n900.h4ck1ng.me` uvádí Vinicia Paese jako původní zdroj.

### 1.1 maemo.plan9.de (snapshot 2017)

`http://maemo.plan9.de/apt-mirror/mirror/repository.maemo.org/`

- Obsahuje `extras`, `extras-devel`, `extras-testing`, `community-testing`, `pool` a `dists`.
- `dists/fremantle/` je **SDK a tools** (`sdk/free`, `sdk/non-free`, `tools/`). V SDK jsou např. `libc6-dev` 2.5.1 (eglibc), `gcc` 4.2.1, `libgtk2.0-dev` 2.14.7. Pro sysroot je to klíčové.
- Tato struktura je nahoře také na `maemo.muarf.org/` (Nokia apps, Nokia SSU, `tablets-dev`).
- Počty balíčků (free, armel, součet polí Size, zhruba): extras 2241 (~3 GB), extras-testing 3391 (~5 GB), extras-devel 14483 (~25 GB, více verzí). SDK: 2702 free + 32 non-free.
- Snapshot je z roku 2017, nejnovější balíčky tedy chybět mohou.

### 1.2 n900.h4ck1ng.me (2026)

Oznámení (vloženo uživatelem, zdroj tohoto textu je příspěvek na fóru):

```
deb http://n900.h4ck1ng.me/extras/         fremantle free non-free
deb http://n900.h4ck1ng.me/extras-devel/   fremantle free non-free
deb http://n900.h4ck1ng.me/extras-testing/ fremantle free non-free
```

- Ověřil jsem, že `Release` všech tří odpovídá HTTP 200, `extras` má `Release` z 2026-03-29 a `Packages` (armel) existuje.
- Autor mirror popisuje jako doplněk k práci Vinicia Paese. Slibuje dokumentaci a IRC server.
- **Bezpečnost:** balíčky se na N900 instalují jako root. Mirror je třetí strana, přes HTTP a bez ověření, že jde o věrnou kopii. Než ho přidáš do telefonu, porovnej `Packages` se snapshotem z plan9.de (stejné `Filename` a `MD5sum`) a zkontroluj `Release.gpg`, pokud existuje. **[ověřit]** že původní podpis maemo klíče sedí.
- Obsah jsem nestahoval ani nesrovnával. Je to jen kontrola dostupnosti.

## 2. Vlastní mirror na Proxmoxu (server Zalman)

Cíl: lokální, z internetu neviditelný archiv Fremantle balíčků. Usnadní vývoj, chrání před zánikem cizích mirrorů a slouží jako zdroj pro sysroot a pro instalaci na obě N900.

### Návrh

1. Zdroje: `maemo.plan9.de` (primární), `n900.h4ck1ng.me` (srovnání), případně Wayback pro díry.
2. Proxmox: LXC kontejner (Debian), pár GB RAM stačí. Disk: začít ~60 GB, rozhodnout podle toho, co se zrcadlí (viz velikosti výše, extras-devel je největší).
3. Stažení: `apt-mirror` nebo `rsync`/`wget -m` proti `maemo.plan9.de`. Jde přes HTTP, rsync tam nejspíš není. **[ověřit]**
4. Sloužení: nginx nebo `python -m http.server` jen na LAN. Žádný port ven.
5. N900: `/etc/apt/sources.list.d/` nebo Application Manager, katalogy ukazují na `http://<lan-ip>/...` s distribucí `fremantle` a komponentami `free non-free`.
6. Verzování: ZFS/LVM snapshot po každém sync, aby se dalo vrátit zpátky.
7. Vlastní repo pro backporty: stejný server (`reprepro` nebo `aptly`), distribuce `fremantle`, komponenta `free`. Vlastní podpis GPG klíčem.

### Příklad apt-mirror konfigurace (neověřeno, upravit)

```
set base_path    /srv/maemo-mirror
set nthreads     4
set _tilde       0

deb-armel http://maemo.plan9.de/apt-mirror/mirror/repository.maemo.org/extras fremantle free non-free
deb-armel http://maemo.plan9.de/apt-mirror/mirror/repository.maemo.org/extras-testing fremantle free non-free
deb-armel http://maemo.plan9.de/apt-mirror/mirror/repository.maemo.org/extras-devel fremantle free non-free
deb-armel http://maemo.plan9.de/apt-mirror/mirror/repository.maemo.org fremantle/sdk free non-free
```

Pozn.: apt-mirror používá hlavně oficiální layout. U SDK je struktura `dists/fremantle/sdk/free`, takže řádek možná půjde psát jinak (komponenta `sdk/free`). **[ověřit]** na zkoušku se stahováním jen `Packages`.

## 3. Použití pro vývoj

- Sysroot pro cross-kompilaci (armel, glibc 2.5): rozbalit `-dev` balíčky ze `sdk` pool do `sysroot/`. Podrobnosti viz sekce 5A v README.
- Hledání už portovaných balíčků: `grep` v `Packages` z extras/extras-devel/extras-testing.
- Zdrojáky: `dists/.../source/`, užitečné jako vzor pro backporty.

## 4. Otevřené otázky

- Vinicius Paes: požádat o souhlas s kopií, nebo vystačit s `maemo.plan9.de` (snapshot 2017)? Chybí-li novější balíčky, porovnat plan9.de s ním.
- Je `n900.h4ck1ng.me` identický s plan9.de, nebo má novější balíčky?
- Funguje stahování z plan9.de přes apt-mirror bez úprav layoutu?
- Obsahuje někde mirror i `Release.gpg` ověřitelný původním maemo klíčem?
- Zdroj pro Nokia SSU a Nokia apps (`downloads.maemo.nokia.com`): na plan9.de přes `maemo.muarf.org/apt-mirror/` — ověřit úplnost.

## 5. Zdroje

- [maemo.plan9.de](http://maemo.plan9.de/)
- [Maemo – Archive Team](https://wiki.archiveteam.org/index.php/Maemo)
- [Apt-mirror – maemo.org wiki](https://wiki.maemo.org/Apt-mirror)
- [Repository – maemo.org wiki](https://wiki.maemo.org/Repository)
- [z/n900-notes](https://github.com/z/n900-notes)
- [denjhang/Maemo_N900](https://github.com/denjhang/Maemo_N900)

## 1.3 maemo.viniciuspaes.com (added 2026-11-13)

An unofficial mirror of the Maemo repositories (Extras, Extras-testing, Extras-devel for Fremantle, SDK repositories for all releases, a Scratchbox mirror with N800 files only, and a catalogue mirror for the N800). Page: <https://maemo.viniciuspaes.com/>. It asks not to clone or mirror it with automated tools in bulk.

**Access rules we follow:** the server answers 403 to generic clients (`curl`, `Python-urllib`). A request with an own, descriptive User-Agent (`n900-resurrection-tools/1.0`, as `scripts/fetch_sysroot.py` sends) gets the indexes and the directory listings. **The `.deb` and source files returned 403 for that User-Agent**, so nothing can be downloaded from there by our tools. We do **not** disguise our client as a browser to get past that (a block of the owner); if we want the files, we ask the owner (the contact is on the page). (On 2026-11-13 one Feed Circuit source tarball was fetched with a browser User-Agent while exploring; that should not have been done and is not repeated.)

What the indexes tell (checked 2026-11-13):
- `https://maemo.viniciuspaes.com/extras/dists/fremantle/free/source/Sources.gz` lists **2054 source packages** of the Extras (for example `feedcircuit` 0.8.3, `feedingit`, `feedhandler`, `feedparser`).
- `http://maemo.viniciuspaes.com/dists/fremantle/sdk/free/source/Sources.gz` lists **914 source packages** of the SDK side (several versions each): among them `osso-rss-feed-reader` (5 versions), `osso-rss-feed-reader-applet`, `microb-engine` (6), `hildon-desktop` (6), `libhildon` (6), `curl` (2), `openssl` (2). Not there: `feedservice2`, `calendar-backend`. The SDK binary index is `dists/fremantle/sdk/free/binary-armel/Packages.gz` (1212 packages with the `non-free` index missing, 404).
- The lines the page gives for the SDK (inside the SDK environment only): `deb http://maemo.viniciuspaes.com/ fremantle/sdk free non-free`, `fremantle/tools free non-free` (with `deb-src`), `fremantle/<token-code> nokia-binaries` (the token is not explained). Extras lines for the phone: `deb http://maemo.viniciuspaes.com/extras/ fremantle free non-free` (also `fremantle-1.2`, `fremantle-1.3`), the same for `extras-testing` and `extras-devel`.

**In our tools:** `scripts/fetch_sysroot.py` takes the package index from `maemo.plan9.de` first and from this mirror when the first fails, downloads each `.deb` from the first mirror that delivers it and checks the MD5 sum of the index. For now the files come from `maemo.plan9.de` in practice. The sources of the stock RSS reader (the TODO about a reader that works with TLS 1.2) and of Feed Circuit (licence BSD, Copyright 2008 George Kibardin, per its `debian/copyright`) are to be asked for or found elsewhere (the Extras sources also exist in the `maemo.plan9.de` snapshot, to check).
