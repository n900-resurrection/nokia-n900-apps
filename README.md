# Vývoj a portování aplikací pro Nokia N900

Pracovní poznámky k návratu k vývoji pro N900 (2 kusy HW). Stav k 2026-11-11.
Související repozitáře:

- [nokia-n900-notes](https://github.com/elPytel/nokia-n900-notes) – odkazy a poznámky

> Poznámka: informace pochází z webového průzkumu (wiki, novinové články, blogy), ne z vlastního ověření.
> Co je označeno **[ověřit]**, je třeba vyzkoušet. Část návodů je stará (2009–2020).

## 1. Cíle a plán

1. Fáze 1: vývoj a testy na virtuálním obrazu (Maemo Leste, případně Maemo 5 emulátor).
2. Fáze 2: testy na reálném N900.
3. Reprodukovatelné build prostředí (Workshop / chroot), aby build nezávisel na hostiteli.

### Upřesnění zadání (2026-11-03)

- Oba N900 běží na **Maemo 5**. Maemo Leste bylo zkoušeno, ale první boot trval extrémně dlouho (viz poznámka o SD kartě v 4.3).
- **Primární cíl: Maemo 5 (Fremantle).** Leste je jen okrajová/volitelná platforma.
- Záměr: **backportovat nové verze open-source aplikací** na staré Maemo 5.
- Důsledek: vlastní VM Maemo Leste (4.1) k tomuto cíli moc nepomůže, protože má jiné ABI, novější knihovny i jiný init. Viz sekce 5A.

## 2. Přehled možností

| Cíl | Varianta | Stav | Poznámka |
|---|---|---|---|
| Maemo Leste | VM, armhf chroot, reálný N900 z SD | nepoužíváme | Jiné ABI i init, pro Maemo 5 k ničemu; zkoušeno na začátku (viz 4.3). |
| Maemo 5 (Fremantle) | Maemo 5 SDK + Scratchbox + QEMU | nepoužíváme | 32bit, nefunguje spolehlivě na 64bit hostiteli, proprietární balíčky. |
| Maemo 5 | Vlastní emulátor GUI (qemu-user + Xvfb + sysroot z telefonu) | **používáme** | Bez hardwaru, viz 4.1. |
| Maemo 5 | Reálné zařízení | **používáme** | Hlavní testovací cíl, viz 4.2. |
| Build prostředí | Ubuntu Workshop (LXD) | **používáme** | Cross toolchain armel + sysroot, viz sekce 3 a 5.1. |

## 3. Ubuntu Workshop

Nástroj Canonicalu vydaný koncem května 2026 pro izolovaná a reprodukovatelná vývojová prostředí.

- Prostředí se definuje v **YAML** (patří do gitu), jeden příkaz je vytvoří, aktualizuje nebo smaže.
- Pod kapotou **LXD**, neprivilegované **systémové kontejnery** (běží init/systemd, víc služeb najednou).
- Prostředí se skládá z **SDK** (jazyky, frameworky, nástroje), které se berou ze SDK Store nebo z vlastního repozitáře. Vlastní SDK jde vytvořit (sesterský projekt SDKcraft).
- Prostředí může dostat přístup k prostředkům hostitele (GUI, SSH agent) přes rozhraní podobná snapd.

### Instalace a použití

```bash
sudo snap install --channel=6/stable lxd      # vyžaduje LXD >= 6.8; jednou `lxd init` (výchozí hodnoty)
sudo snap install --classic workshop          # ověřeno s verzí 0.9.9
make up                                       # = workshop launch n900 podle .workshop/n900.yaml
make toolchain && make sysroot                # akce z YAML: cross toolchain a sysroot z Fremantle SDK
workshop -p . exec n900 -- <příkaz>           # jednorázový příkaz; make enter = interaktivní shell
```

Prostředí je definované v [.workshop/n900.yaml](.workshop/n900.yaml): `name`, `base: ubuntu@24.04` a pojmenované `actions` (shellové příkazy spouštěné `workshop run n900 -- <akce>`; `toolchain`, `sysroot`, `cpp-hello`, `pylibs`). Projekt je v kontejneru jako `/project`, uživatel `workshop` má `sudo` bez hesla.
Příkazy, formát souboru a zjištěné zvláštnosti (výstup bez TTY, Docker na hostiteli): [DOC/workshop-crosscompile.md](DOC/workshop-crosscompile.md). Oficiální dokumentace: <https://ubuntu.com/workshop/docs/>.

### Uplatnění pro N900

- Čisté prostředí s armel cross-toolchainem (GCC 13.3) a sysrootem z Fremantle SDK, v něm se staví všechny balíčky v `apps/` včetně Pythonu 3.11 a OpenSSL 3.
- ARM binárky se zkouší přímo pod `qemu-arm` (qemu-user) proti sysrootu, bez debootstrapu a `binfmt_misc`; stejně běží emulátor GUI (sekce 4.1) a `make qemu-test`.
- Izolace experimentů a AI agentů od hostitele.

Srovnání: Docker/Dev Containers = lehké jednoprocesové kontejnery. Nix shell = reprodukovatelnost přes balíčky na hostiteli. Workshop = plnohodnotný systémový kontejner s deklarativním YAML.

## 4. Virtualizace a emulace

Primární cíl je skutečný Maemo 5, takže tady je jen to, co se osvědčilo, a to, co se zkoušelo a nepoužívá.

### 4.1 Emulátor Fremantle ve Workshopu (používáme)

Oficiální Maemo 5 SDK (Scratchbox + QEMU) se nepoužívá: potřebuje starý 32bit systém a proprietární Nokia balíčky. Místo něj je vlastní emulátor
nad stejnými knihovnami jako na telefonu ([DOC/hildon-python3.md](DOC/hildon-python3.md)):

- ARM programy (Python 2.5 s PyGTK, Python 3.11, C) běží pod `qemu-arm` proti sysrootu s **GTK 2.14 a Hildon 2.2** a motivem, písmem a ikonami z telefonu, obraz jde na virtuální obrazovku Xvfb 800×480 (VNC).
- `make hildon-overlay` (jednou) doplní do sysrootu motiv, písma a Python 2.5 z telefonu; `make hildon-run APP=<app>` spustí jednu aplikaci, `make emulator` celou plochu (horní lišta, přepínač úloh, mřížka aplikací); `make screenshots` snímky.
- D-Bus mocky (osso, MAFW) a testy bez telefonu: `make emu-test`, `make hildon-test`, `make qemu-test`.
- Omezení: hildon-desktop nejde (clutter + OpenGL ES), žádné widgety plochy, žádný hardware (kamera, Bluetooth, GPIO, modem). To se ověřuje jen na telefonu.

### 4.2 Reálný N900 (hlavní testovací cíl)

Přístup přes SSH alias `n900` (klíč, root přes `su`), nasazení `make push` / `make install`, automatické testy `make test` ([DOC/testing.md](DOC/testing.md)). Co je na telefonu těsné: kořen na NAND (~60 MB volných, balíčky patří do `/opt`),
`/tmp` je tmpfs o 1 MB (build `pip` potřebuje `TMPDIR` v domovském adresáři), `MyDocs` je FAT s `noexec`. Další poznámky o zařízení: [DOC/n900.md](DOC/n900.md).

### 4.3 Maemo Leste (nepoužívá se)

Zkoušeno na začátku, od rozhodnutí 2026-11-03 jen okrajová platforma: jiné ABI (armhf), novější knihovny, jiný init, takže ničemu pro Maemo 5 nepomůže; první boot z SD trval extrémně dlouho a nefunguje Bluetooth, kamera ani A-GPS.
Pokud by se k němu někdo vrátil: obrazy VM na <https://maedevu.maemo.org/images/virtual-machines/> (QEMU s SATA diskem, ne `virtio`), armhf chroot přes `debootstrap` + `qemu-user-static`, vývojový zdroj `daedalus-devel` (komponenta `n900`), na SD kartě `dd` obrazu a U-Boot, doporučena SDXC U3.
**[ověřit]** aktuální suite a verze obrazů; poznámky výše pocházejí z wiki a nebyly znovu ověřeny.

## 5. Cross-kompilace

### 5.1 Maemo 5: armel (používáme)

Ověřený postup, který používají všechny aplikace v `apps/`:

- Workshop `n900` (Ubuntu 24.04, LXD): `make up`, `make toolchain` (`gcc-arm-linux-gnueabi` 13.3, `qemu-user`, nástroje), `make sysroot` ([scripts/fetch_sysroot.py](scripts/fetch_sysroot.py): `-dev` balíčky z Fremantle SDK, glibc 2.5).
- Překladač: [scripts/maemo-gcc](scripts/maemo-gcc) (`-march=armv7-a -mfpu=neon -mfloat-abi=softfp`, linker gold, `-fgnu89-inline`, `MAEMO_DEPS` pro novější knihovny); výsledek odkazuje nejvýš na `GLIBC_2.4`.
- Novější knihovny (OpenSSL 3, mbedTLS, zlib, ncurses, libevent) se staví staticky nebo do vlastního prefixu v `/opt`, aby se nerozbil systém. Jazyky: C, Go, Rust (staticky), Python 3.11 ([apps/python3](apps/python3/python3.md)).
- Binárka odpovídá soft-float ABI (armel); `arm-linux-gnueabihf` na Maemo 5 nepoběží.

Detaily: [DOC/workshop-crosscompile.md](DOC/workshop-crosscompile.md). Nasazení: `scp` do `/home/user/apps/` nebo `.deb` přes `dpkg -i` / apt repozitář (sekce 5.2).

### 5.2 Balíčky a repozitář

Každá aplikace má `apps/<app>/Makefile` nad [mk/app.mk](mk/app.mk): `make -C apps/<app> build|deb|push|install|test`. `make debs` postaví všechny `.deb`, `make repo` z nich složí apt repozitář (podmodul
`n900-repository`, publikovaný na GitHub Pages, ~60 balíčků, přes `apt-transport-curl` s TLS 1.3). Podpis repozitáře a Správce aplikací zatím nejsou hotové, viz [TODO.md](TODO.md).

### 5.3 armhf (jen pro Maemo Leste)

```bash
sudo apt install crossbuild-essential-armhf debootstrap qemu-user-static binfmt-support
```

`debootstrap --arch=armhf --foreign <suite> ./armhf-root <mirror>` + `qemu-arm-static` + `chroot` a `dpkg-buildpackage -aarmhf`. Pro Maemo 5 se nepoužívá.

## 5A. Maemo 5: backportování nového software

### Cílové prostředí (Fremantle)

- Architektura **armel**, **glibc 2.5**, jádro 2.6.28-omap1, GTK2/Hildon, 256 MB RAM, Cortex-A8 s NEON; systémový glib 2.20, OpenSSL 0.9.8n, TLS jen 1.0.
- Nový upstream kód proto často potřebuje: novější kompilátor (máme GCC 13 z cross toolchainu), statické nebo vlastní knihovny v `/opt`, záplaty pro chybějící syscally a funkce ve staré glibc (`getrandom`, `memfd`, novější `stat`) a úpravy pro jádro 2.6.28 (Go runtime, `rlimit` sandbox u OpenSSH).
- Novější GLib 2.66 je k dispozici jako statická závislost ([apps/glib2](apps/glib2/glib2.md), ověřeno na telefonu); irssi, mc a profanity už na ní běží; WeeChat GLib nepotřebuje.

### Co se osvědčilo

| Varianta | Stav | Komentář |
|---|---|---|
| Moderní cross-compiler + sysroot z `-dev` balíčků ve Workshopu | **používáme** | Viz sekce 5.1. Ověřeno na telefonu desítkami balíčků. |
| Oficiální Maemo 5 SDK (Scratchbox) | nepoužíváme | Starý 32bit host, proprietární balíčky, nepraktické. |
| Build přímo na N900 | výjimečně | 256 MB RAM, pomalé CPU; hodí se jen na malé věci. |

### Postup backportu jedné aplikace

1. Najít upstream a ověřit závislosti (`make updates` porovná naše verze s nejnovějším vydáním).
2. `apps/<app>/build.sh` (překlad přes `scripts/maemo-gcc`, závislosti do `build/deps`), případně záplaty v `apps/<app>/`.
3. `make -C apps/<app> deb` a test v qemu nebo v emulátoru, pak `make push` / `install` na telefon a `make test`.
4. Dokument `apps/<app>/<app>.md`, položka v [TODO.md](TODO.md) a zařazení do `make repo`.
5. Aplikace s vlastním životem (hildonlite, selfie, mutt-hildon, signal-bridge…) jsou samostatné submoduly.

### Komunita a zdroje balíčků

- Originál `repository.maemo.org` je mrtvý; žijí `maemo.plan9.de` (snapshot 2017, včetně SDK) a `n900.h4ck1ng.me`, viz [DOC/mirror.md](DOC/mirror.md).
- Doporučeno mít na zařízeních CSSU (komunitní aktualizace Maemo 5) **[ověřit]**; fórum talk.maemo.org (sekce Maemo 5), r/N900.

### Co je hotové a co zbývá

- [TODO.md](TODO.md)

### Plán dalšího vývoje

- [Roadmapa: e-mail, feedy a podcasty, kontakty a kalendář, rádio a audioknihy, vlastní Hildon aplikace](DOC/roadmap.md)

### Struktura a balíčky

- [Rozbor: struktura repa, závislosti, .deb, lokální repo, GitHub](DOC/packaging.md)
- Každá aplikace je v `apps/<app>/` s vlastním `Makefile` (`build`, `deb`, `push`, `install`…), příklad:
  [apps/wordgrinder](apps/wordgrinder/README.md). Společná část Makefile je v [mk/common.mk](mk/common.mk).
- Přehled příkazů: `make` (kořen) a `make -C apps/wordgrinder`.
- Část aplikací je v samostatných repozitářích jako git submoduly (`hildonlite`, `selfie`, `mutt-hildon`, `signal-bridge`, `n900-repository` a další, viz `.gitmodules`). Klonuj s `git clone --recursive` nebo následně `git submodule update --init`.

### Cross-kompilace ve Workshopu

- [Syntaxe Workshopu, definice prostředí a sysroot](DOC/workshop-crosscompile.md)
- Prostředí: [.workshop/n900.yaml](.workshop/n900.yaml), skript sysrootu: [scripts/fetch_sysroot.py](scripts/fetch_sysroot.py)
- Stav (2026-11-03): Workshop `n900` běží, toolchain (GCC 13.3, armel) a sysroot z Fremantle SDK jsou nainstalované. [src/c/hello/hello.c](src/c/hello/hello.c) (viz [src/README.md](src/README.md)) se přeloží přes [scripts/maemo-gcc](scripts/maemo-gcc), odkazuje jen na `GLIBC_2.4` a spustí se pod qemu-user proti sysrootu s glibc 2.5. **Ověřeno i na skutečném N900** (2026-11-04, kernel 2.6.28-omap1, `make push` + spuštění, vypsalo `Hello from Maemo 5 (armel, glibc 2.5)`). Binárky nejdou spouštět z `/home/user/MyDocs` (FAT, `noexec`), kopíruj do `/home/user/apps/` (výchozí `DEST`). Přístup: SSH klíčem přes alias `n900` v `~/.ssh/config`, viz `.env`.
- Pozor: SDK má jen **OpenSSL 0.9.8n**, pro Python 3.11 je potřeba vlastní novější OpenSSL.

### Repozitáře a vlastní mirror

- [Stav mirrorů a plán vlastního mirroru na Proxmoxu](DOC/mirror.md): originál `repository.maemo.org` je nedostupný, žijí `maemo.plan9.de` (snapshot 2017, včetně SDK) a `n900.h4ck1ng.me` (2026).

### Konkrétní aplikace (jedna aplikace = jeden soubor v `DOC/`)

- [WordGrinder](apps/wordgrinder/wordgrinder.md): konzolový textový procesor, první kandidát.
- Malé ncurses programy: [cmatrix](apps/cmatrix/cmatrix.md), [cbonsai](apps/cbonsai/cbonsai.md), [tty-clock](apps/tty-clock/tty-clock.md).
- [curl 8.23 (TLS 1.3)](apps/curl/curl.md): moderní HTTPS na starém systému, staticky s mbedTLS.
- [git 2.56](apps/git/git.md): nahrazuje `git 1.6.2`, HTTPS přes libcurl (potřebuje `curl`).
- [htop 3](apps/htop/htop.md): nový htop vedle systémového 0.8.3 (balíček `htop3`), měření výkonu.
- [Bash 5.3](apps/bash/bash.md) (balíček `bash5`) a [BusyBox 1.37](apps/busybox/busybox.md) (balíček `busybox37`): moderní shell a nástroje vedle systémových; testy viz [DOC/testing.md](DOC/testing.md).
- [ntp-sync](apps/ntp-sync/ntp-sync.md): nastavení času přes NTP (GUI volba používá čas operátora, bez SIM nefunguje).
- [Go](apps/go/go.md): křížový překlad Go programů (statická binárka, TLS 1.3); runtime potřebuje úpravu kvůli jádru 2.6.28.
- [OpenSSL 3](apps/openssl/build.sh): statická knihovna jako závislost (ne balíček).
- [GLib 2.66](apps/glib2/glib2.md): statická knihovna (glib, gobject, gio) jako závislost, systémová GLib 2.20 zůstává.
- [irssi 1.4.5](apps/irssi/irssi.md): IRC klient v terminálu (TLS 1.3, statická GLib 2.66, OpenSSL 3, ncursesw); ověřeno připojením na Libera.Chat.
- [Midnight Commander 4.8.33](apps/mc/mc.md): správce souborů ve dvou panelech (`mc`, `mcedit`, `mcview`), statická GLib 2.66 a ncursesw; ověřeno spuštěním na telefonu.
- [WeeChat 4.10](apps/weechat/weechat.md): chat klient (IRC) v terminálu, TLS přes statické GnuTLS ([apps/gnutls](apps/gnutls/gnutls.md)); ověřeno připojením na Libera.Chat.
- [Profanity 0.19](apps/profanity/profanity.md): XMPP (Jabber) klient v terminálu (statická GLib 2.66, libstrophe s OpenSSL 3, SQLite); bez OMEMO; zatím ověřeno jen spuštění.
- [Mutt 2.4](apps/mutt/mutt.md) a [msmtp 1.8](apps/msmtp/msmtp.md): terminálový e-mail s TLS 1.3 (čtení IMAP, odesílání přes msmtp).
- [Python 3.11](apps/python3/python3.md): CPython pro N900 s ssl (OpenSSL 3.5, TLS 1.3), sqlite3, curses; [rozbor původního repozitáře](DOC/python3-repo-review.md).
- [camel-lite-ssl3](apps/camel-lite/camel-lite.md): knihovna Modestu s OpenSSL 3 (TLS 1.2/1.3 v systémovém e-mailu).
- [mutt-hildon 0.4](apps/mutt-hildon/mutt-hildon.md): grafický e-mail (Hildon, Python 2.5) nad curl, msmtp a Muttem.
- [apt-transport-curl 0.1](apps/apt-transport-curl/README.md): apt přes HTTPS s TLS 1.2/1.3 (metoda `https` přes curl 8), nutné pro repozitář na GitHub Pages; [DOC/apt-repo.md](DOC/apt-repo.md): `make repo`.
- [sfeed 2.4](apps/sfeed/sfeed.md): RSS/Atom a podcasty v terminálu (stahování přes curl, TLS 1.3).
- [jq 1.8](apps/jq/jq.md) a [Wget 1.25 (TLS 1.3)](apps/wget/wget.md): JSON na příkazové řádce a `wget`, který umí moderní HTTPS.
- [xml-tools 2.15](apps/xml-tools/xml-tools.md): `xmllint` a `xsltproc` (libxml2 + libxslt, staticky); telefon má jen starou knihovnu bez nástrojů.
- [smb 0.1](apps/smb/smb.md): klient SMB2/SMB3 (`ls`, `get`, `put`, `mv` ...) nad libsmb2, staticky; bez připojení jako disk (jádro nemá `cifs`).
- [hildonlite 0.3](apps/hildonlite/README.md) (subrepo, balíček `python3-hildonlite`, i pip): GUI pro Python 3 (GTK2/Hildon přes ctypes), okna, seznamy, dialogy, `on_key`; [rozbor](DOC/hildon-python3.md). Testy: `make hildon-test`.
- [selfie 0.6](apps/selfie/README.md) (subrepo): náhled přední/zadní kamery a focení (GStreamer `camerabin` + `libomap3cam`, správné barvy), půlstisk HW tlačítka kamery jako spoušť.
- [Bluetooth klávesnice](DOC/bluetooth-keyboard.md): párování, rozdělení zařízení přes uinput, české rozložení v uživatelském prostoru, opakovatelný postup ve [scripts/bt-keyboard/](scripts/bt-keyboard/bt-keyboard.sh).
- [bt-kbmouse 0.1](apps/bt-kbmouse/README.md) (subrepo): služba a nastavení pro Bluetooth klávesnici s TrackPointem: rozložení, viditelný pointer s nastavitelnou rychlostí, rolování prostředním tlačítkem; [rozbor myši](DOC/mouse.md) a upravený evdev ovladač.
- [Testy na telefonu](DOC/testing.md): `make test`.
- [E-mail Centrum](DOC/email-centrum.md): nastavení serverů (IMAP/SMTP), curl a Modest, bez hesla.
- Plány: [roadmapa](DOC/roadmap.md) (TLS, e-mail, feedy, audio, Audiobookshelf), [messengery](DOC/messengers.md).

### Kandidáti na backport (bude třeba vybrat)

Vhodné jsou malé aplikace v C/C++ s minimem závislostí (terminálové nástroje, textové editory, malé hry, SDL). Náročné jsou věci s Rust/Go/moderním C++ nebo s novým Qt/GTK, protože ty cílí na mnohem novější knihovny.

## 6. Postup (jak to dnes děláme)

1. `make up && make toolchain && make sysroot`: Workshop s toolchainem a sysrootem (jednou).
2. Nová aplikace: `apps/<app>/` s `Makefile`, `build.sh`, `package.sh`; `make -C apps/<app> deb`.
3. Zkouška bez telefonu: `make hildon-run APP=<app>` (GUI), `make qemu-test` / `make emu-test`, `make hildon-test`.
4. Zkouška na telefonu: `make -C apps/<app> install` a `make -C apps/<app> test` (SSH alias `n900`); zásahy do systému jen se souhlasem.
5. Publikace: `make repo` (v hlavním repu) složí `n900-repository/`, nové verze se přidávají do `pool/`; push repozitáře `n900-repository`, podrepozitářů a nakonec hlavního repa.
6. Poznatky: dokument v `DOC/` (nové psát anglicky), úkoly v [TODO.md](TODO.md), případně blog.

## 7. Otevřené otázky

Vyřešeno:

- Primární cíl je Maemo 5 (armel, glibc 2.5); Leste jen okrajově.
- Zrcadlo Fremantle SDK a `-dev` balíčků: `maemo.plan9.de` a `n900.h4ck1ng.me` ([DOC/mirror.md](DOC/mirror.md)).
- Cross-kompilace ve Workshopu funguje, binfmt/qemu-user v kontejneru také (emulátor i testy `make qemu-test`).
- Backportováno a ověřeno na telefonu: moderní TLS (curl, git, wget), Python 3.11, e-mail (Mutt, msmtp, camel-lite), terminálové nástroje, gPodder, hildonlite, selfie, Bluetooth klávesnice.

Zbývá:

- Správce aplikací zamrzá, instalace jde zatím jen přes `apt-get`; chybí podpis repozitáře (viz [TODO.md](TODO.md)).
- Které aplikace dál (Jellyfin klient, Signal v nativním UI, další terminálové nástroje)? Plán: [DOC/roadmap.md](DOC/roadmap.md).
- Instalovat CSSU na obě zařízení?
- Jak dlouho držet staré verze balíčků v `pool/`?
- Trvalé zprovoznění Bluetooth klávesnice (moduly při startu, upstart job): čeká na souhlas.

## Zdroje

- [Maemo Leste – Development](https://leste.maemo.org/Development)
- [Maemo Leste – Nokia N900](https://leste.maemo.org/Nokia_N900)
- [Maemo Leste – Virtual Machine](https://leste.maemo.org/Virtual_Machine)
- [Maemo 5 Final SDK Installation](https://wiki.maemo.org/Documentation/Maemo_5_Final_SDK_Installation)
- [Maemo SDK: vyvíjíme pro mobilní Linux (root.cz, Martin Malý, 26. 11. 2009)](https://www.root.cz/clanky/maemo-sdk-vyvijime-pro-mobilni-linux/): úvod do Maemo 5 SDK (Scratchbox, Xephyr, `af-sb-init.sh`, `run-standalone`, GTK+ Hello World). Odkazy z článku: [Maemo 5 Developer Guide](https://wiki.maemo.org/Documentation/Maemo_5_Developer_Guide), [Maemo SDK Virtual Images](https://wiki.maemo.org/Documentation/Maemo_5_Developer_Guide/Development_Environment/Maemo_SDK_Virtual_Images), [spouštíme SDK](https://wiki.maemo.org/Documentation/Maemo_5_Developer_Guide/Development_Environment/Maemo_SDK), [PyMaemo: Hello world](https://wiki.maemo.org/PyMaemo/UITutorial/Getting_started), [maemo.org](https://maemo.org), [Maemo Wiki](https://wiki.maemo.org/Main_Page), [maemo-guru.com](http://www.maemo-guru.com), [maemo-freak.com](http://www.maemo-freak.com), [maemo-apps.org](http://www.maemo-apps.org).
- [Devuan on N900 (wiki.maemo.org)](https://wiki.maemo.org/Devuan_on_N900)
- [debian900](https://github.com/dderby/debian900)
- [Ubuntu Workshop – blog](https://ubuntu.com/blog/introducing-workshop-sandboxed-development-environments)
- [Ubuntu Workshop – docs](https://ubuntu.com/workshop/docs/)
- [Phoronix](https://www.phoronix.com/news/Canonical-Ubuntu-Workshop), [9to5Linux](https://9to5linux.com/canonical-launches-ubuntu-workshop-for-sandboxed-development-environments)
