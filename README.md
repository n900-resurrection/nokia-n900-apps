# Vývoj a portování aplikací pro Nokia N900

Pracovní poznámky k návratu k vývoji pro N900 (2 kusy HW). Stav k 2026-11-03.
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
| Maemo Leste | VM (VirtualBox / QEMU amd64) | použitelné | Nejjednodušší start. Wiki stránka je „stub“, nabízené obrazy mohou být staré. |
| Maemo Leste | armhf chroot + `qemu-user-static` | použitelné | Doporučeno pro buildy balíčků pro N900. |
| Maemo Leste | reálný N900 z SD karty | podporováno | Kernel 6.18 LTS, 3D akcelerace, telefon, Wi-Fi. |
| Maemo 5 (Fremantle) | Maemo 5 SDK + Scratchbox + QEMU | historické | 32bit, nefunguje spolehlivě na 64bit hostiteli. Potřeba Nokia balíčky. |
| Maemo 5 | Reálné zařízení | funguje | Pro ověření nativních Maemo 5 aplikací. |
| Build prostředí | Ubuntu Workshop (LXD) | nové (květen 2026) | Viz sekce 3. |

## 3. Ubuntu Workshop

Nástroj Canonicalu vydaný koncem května 2026 pro izolovaná a reprodukovatelná vývojová prostředí.

- Prostředí se definuje v **YAML** (patří do gitu), jeden příkaz je vytvoří, aktualizuje nebo smaže.
- Pod kapotou **LXD**, neprivilegované **systémové kontejnery** (běží init/systemd, víc služeb najednou).
- Prostředí se skládá z **SDK** (jazyky, frameworky, nástroje), které se berou ze SDK Store nebo z vlastního repozitáře. Vlastní SDK jde vytvořit (sesterský projekt SDKcraft).
- Prostředí může dostat přístup k prostředkům hostitele (GUI, SSH agent) přes rozhraní podobná snapd.

### Instalace

```bash
sudo snap install --channel=6/stable lxd      # vyžaduje LXD >= 6.8
sudo snap install --classic workshop
workshop launch <nazev>                        # dle článků; přesnou syntaxi ověřit v dokumentaci
```

Oficiální dokumentace: <https://ubuntu.com/workshop/docs/> (sekce *Workshop configuration*, *Using workshops*, *SDK development*, *Reference*).

**[ověřit]** Přesný formát definičního souboru a CLI jsem z dostupných zdrojů nezískal, proto zde není vymyšlený příklad YAML.

### Uplatnění pro N900

- Čisté prostředí s armhf cross-toolchainem, Pythonem a OpenSSL pro [Python_3.11_on_N900](https://github.com/elPytel/Python_3.11_on_N900).
- Uvnitř kontejneru lze použít debootstrap + qemu-user-static (viz sekce 5). **[ověřit]** zda to v neprivilegovaném kontejneru funguje (binfmt_misc je vlastnost jádra hostitele).
- Izolace experimentů a AI agentů od hostitele.

Srovnání: Docker/Dev Containers = lehké jednoprocesové kontejnery. Nix shell = reprodukovatelnost přes balíčky na hostiteli. Workshop = plnohodnotný systémový kontejner s deklarativním YAML.

## 4. Virtualizace Maemo

### 4.1 Maemo Leste ve VM (amd64)

Obrazy: <https://maedevu.maemo.org/images/virtual-machines/> (formáty `.vdi.xz`, `.qcow2`, Vagrant).

QEMU (příklad z wiki):

```bash
qemu-system-x86_64 -hda maemo-leste-1.0-amd64.qcow2 -enable-kvm -cpu host -smp cores=2 -m 1024
```

VirtualBox: `xz -d` na `.vdi.xz`, nový stroj „Debian (64-bit)“, 1024 MB RAM, obraz jako disk.

Známé potíže:

- QEMU/libvirt: s `virtio` diskem se obraz nespustí, pomůže sběrnice **SATA**.
- VirtualBox: může být nutné vypnout integraci myši a ručně nastavit síť.

VM je amd64, neověří tedy ARM specifika (NEON, výkon, 256 MB RAM, rozlišení 800×480).

### 4.2 Maemo Leste armhf (chroot + qemu-user)

Wiki doporučuje: `debootstrap` + `qemu-user-static` + `binfmt-support` (nebo `systemd-nspawn`). Příklady na wiki používají staré sady (Stretch / ascii), **je potřeba doplnit aktuální suite** (Leste je postaven na Devuan, aktuální vývoj `daedalus-devel`). **[ověřit]**

Vývojový apt zdroj: `daedalus-devel` z maedevu.maemo.org, komponenta `n900` pro cross-build na N900.

### 4.3 Maemo Leste na skutečném N900

- Obraz na microSD (`dd` nebo Etcher), doporučena karta **SDXC U3** (Class 10 U1 je pomalá).
- Bootloader: U-Boot přes `0xFFFF` (nebo `u-boot-flasher` z existujícího Fremantle). Trvalé flashnutí U-Bootu (`-f`) nahradí kernel Fremantle, nejdřív zajistit možnost obnovy.
- První boot trvá minimálně 3 minuty, nepoužívat Wi-Fi do druhého bootu, spustit `/etc/expandcard.sh`.
- Nefunguje: Bluetooth, FM přijímač, A-GPS, kamera, USB OTG. Nepoužívat zram/zswap. Do `/home/user` dát `.nomedia`, aby Tracker nezpomaloval systém.
- Vlastní obraz: `debos` z repozitáře `leste-cicd`.

### 4.4 Maemo 5 (Fremantle) – emulace

- Oficiální cesta: Maemo 5 Final SDK, Scratchbox jako cross prostředí a QEMU emulátor (UI přes Xephyr). Instalace: [Maemo 5 Final SDK Installation](https://wiki.maemo.org/Documentation/Maemo_5_Final_SDK_Installation).
- Omezení: Scratchbox obvykle nefunguje na 64bit systémech, emulátor potřebuje proprietární Nokia balíčky (EULA) a obraz, jehož dostupnost je nejistá. ARM target pod QEMU nefunguje dobře, na desktopu se používá x86 target.
- Praktický závěr: Maemo 5 testovat primárně na reálném zařízení. Kandidát pro Workshop: starý 32bit Ubuntu/Debian kontejner se Scratchboxem. **[ověřit]**
- Nenašel jsem N900 model ve `qemu-system-arm`; obecné armhf VM (`vexpress-a9`) nereprezentují HW N900.

## 5. Nastavení cross-kompilace (armhf)

### 5.1 Přímý cross-toolchain (Ubuntu 24.04)

```bash
sudo apt install build-essential crossbuild-essential-armhf \
  gcc-arm-linux-gnueabihf g++-arm-linux-gnueabihf
arm-linux-gnueabihf-gcc --version
```

Python 3.11 – klíčové volby (z repozitáře Python_3.11_on_N900):

```bash
./configure --build="$(./config.guess)" --host=arm-linux-gnueabihf \
  --prefix="$PWD/python-arm-install" --enable-optimizations --enable-shared \
  --disable-ipv6 --without-ensurepip --with-build-python=/usr/bin/python3.11 \
  ac_cv_file__dev_ptmx=no ac_cv_file__dev_ptc=no
file python-arm-install/bin/python3.11    # očekávat: ELF 32-bit ARM
```

Pasti:

- Hostitelský Python musí mít stejnou verzi jako cílový (3.11).
- Modul `ssl` potřebuje OpenSSL >= 1.1.1 pro armhf (`compile_OpenSSL.sh` je zatím nedokončený).
- Bez `--disable-ipv6` configure padá na `getaddrinfo()`.
- Binárka musí odpovídat glibc na cíli (N900 Maemo 5 má starou glibc, **[ověřit]** kompatibilitu; Maemo Leste je novější).

### 5.2 Debian multiarch / chroot (doporučeno pro `.deb` balíčky)

```bash
sudo apt install debootstrap qemu-user-static binfmt-support
sudo debootstrap --arch=armhf --foreign <suite> ./armhf-root <mirror>
sudo cp /usr/bin/qemu-arm-static ./armhf-root/usr/bin/
sudo chroot ./armhf-root /debootstrap/debootstrap --second-stage
# build balíčku:
dpkg-buildpackage -aarmhf
```

`<suite>` a `<mirror>` doplnit podle cílového systému (Devuan / Maemo Leste repo). Výhoda: nativní závislosti, správné knihovny, `.deb` na výstupu.

### 5.3 Nasazení na zařízení

```bash
scp balicek_armhf.deb user@<ip-n900>:/home/user/MyDocs/
ssh user@<ip-n900> 'dpkg -i /home/user/MyDocs/balicek_armhf.deb'   # Maemo 5: root přes sudo/gainroot
```

## 5A. Maemo 5: backportování nového software

### Cílové prostředí (Fremantle)

- Architektura **armel** (soft-float, ne armhf!). Binárky z `arm-linux-gnueabihf` na Maemo 5 nepoběží.
- **glibc 2.5**, původní kompilátor GCC 4.2.1 (podle poznámek k Maemo 5 SDK; **[ověřit]** přesné verze v SDK repozitáři).
- Starý toolkit GTK2/Hildon, jádro 2.6.28 (Maemo 5), 256 MB RAM, Cortex-A8 s NEON.
- Systém je zastaralý, takže nový upstream kód často vyžaduje:
  - nižší C/C++ standard nebo novější kompilátor staticky/cross (GCC 4.2 je pro moderní kód nepoužitelný),
  - případně staticky slinkované závislosti nebo vlastní knihovny v `/opt` (aby se nerozbil systém),
  - záplaty pro chybějící syscalls a funkce ve starší glibc (např. `getrandom`, `memfd`, novější `pthread`/`stat` varianty).

### Možnosti toolchainu

| Varianta | Stav | Komentář |
|---|---|---|
| Oficiální Maemo 5 SDK (Scratchbox 1) | historické | Potřebuje starý 32bit hostitel a `mmap_min_address <= 4096`. ARMEL target pod qemu-user má problém se spuštěním UI. Nejvěrnější prostředí, ale nepraktické. |
| Moderní cross-compiler + sysroot z `-dev` balíčků | dle jednoho projektu funguje | [denjhang/Maemo_N900](https://github.com/denjhang/Maemo_N900): Ubuntu 22.04, `arm-linux-gnueabi` (armel), sysroot z oficiálních `-dev` balíčků a glibc 2.5. Autor uvádí, že binárky běží na skutečném N900. **[ověřit]**, jde o jediný osobní projekt. |
| Docker / Scratchbox 2 pro Fremantle | nenalezeno | Nenašel jsem ověřený hotový obraz. Vlastní sestavení je kandidát na Workshop SDK. |
| Build přímo na N900 | možné, pomalé | Pro malé věci. 256 MB RAM a pomalé CPU, nutný swap. |

### Navržený postup pro Workshop prostředí

1. Základ: Ubuntu 22.04/24.04 kontejner s `gcc-arm-linux-gnueabi` (armel).
2. Sysroot: stáhnout `-dev` balíčky pro Fremantle z archivu SDK repozitáře (zdroj ověřit, originál `repository.maemo.org` může být nedostupný nebo přesunutý) a rozbalit do `sysroot/`.
3. Použít `--sysroot=...`, `-march=armv7-a -mfpu=neon -mfloat-abi=softfp` (softfp, protože Maemo 5 je armel). **[ověřit]** přesné flagy proti SDK.
4. Zkušební cíl: Hello World, potom Hildon/GTK aplikace, potom backport vybraného projektu.
5. Balení do `.deb` (armel) a instalace na zařízení přes `dpkg -i` nebo `apt` z vlastního repa.

### Kde se hledat repozitáře a komunitu

- Extras-devel (`deb http://repository.maemo.org/extras-devel/ fremantle free non-free`) pro vývojové balíčky. Dostupnost zrcadel **[ověřit]**.
- Community SSU (CSSU) je komunitní aktualizace Maemo 5 (oznámena 2011). Doporučuji mít na zařízeních nainstalovaný, jelikož běžní vývojáři cílí na něj. **[ověřit]**
- Fórum talk.maemo.org (Maemo 5 sekce), pro zjištění, co už je portované.

### Co je hotové a co zbývá

- [TODO.md](TODO.md)

### Plán dalšího vývoje

- [Roadmapa: e-mail, feedy a podcasty, kontakty a kalendář, rádio a audioknihy, vlastní Hildon aplikace](DOC/roadmap.md)

### Struktura a balíčky

- [Rozbor: struktura repa, závislosti, .deb, lokální repo, GitHub](DOC/packaging.md)
- Každá aplikace je v `apps/<app>/` s vlastním `Makefile` (`build`, `deb`, `push`, `install`…), příklad:
  [apps/wordgrinder](apps/wordgrinder/README.md). Společná část Makefile je v [mk/common.mk](mk/common.mk).
- Přehled příkazů: `make` (kořen) a `make -C apps/wordgrinder`.

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
- [Mutt 2.4](apps/mutt/mutt.md) a [msmtp 1.8](apps/msmtp/msmtp.md): terminálový e-mail s TLS 1.3 (čtení IMAP, odesílání přes msmtp).
- [Python 3.11](apps/python3/python3.md): CPython pro N900 s ssl (OpenSSL 3.5, TLS 1.3), sqlite3, curses; [rozbor původního repozitáře](DOC/python3-repo-review.md).
- [camel-lite-ssl3](apps/camel-lite/camel-lite.md): knihovna Modestu s OpenSSL 3 (TLS 1.2/1.3 v systémovém e-mailu).
- [mutt-hildon 0.4](apps/mutt-hildon/mutt-hildon.md): grafický e-mail (Hildon, Python 2.5) nad curl, msmtp a Muttem.
- [apt-transport-curl 0.1](apps/apt-transport-curl/apt-transport-curl.md): apt přes HTTPS s TLS 1.2/1.3 (metoda `https` přes curl 8), nutné pro repozitář na GitHub Pages; [DOC/apt-repo.md](DOC/apt-repo.md): `make repo`.
- [sfeed 2.4](apps/sfeed/sfeed.md): RSS/Atom a podcasty v terminálu (stahování přes curl, TLS 1.3).
- [jq 1.8](apps/jq/jq.md) a [Wget 1.25 (TLS 1.3)](apps/wget/wget.md): JSON na příkazové řádce a `wget`, který umí moderní HTTPS.
- [Testy na telefonu](DOC/testing.md): `make test`.
- [E-mail Centrum](DOC/email-centrum.md): nastavení serverů (IMAP/SMTP), curl a Modest, bez hesla.
- Plány: [roadmapa](DOC/roadmap.md) (TLS, e-mail, feedy, audio, Audiobookshelf), [messengery](DOC/messengers.md).

### Kandidáti na backport (bude třeba vybrat)

Vhodné jsou malé aplikace v C/C++ s minimem závislostí (terminálové nástroje, textové editory, malé hry, SDL). Náročné jsou věci s Rust/Go/moderním C++ nebo s novým Qt/GTK, protože ty cílí na mnohem novější knihovny.

## 6. Doporučený postup (návrh)

1. Spustit Maemo Leste amd64 VM a seznámit se s prostředím (Hildon, apt, `daedalus-devel`).
2. Postavit armhf chroot a vybudovat testovací balíček (hello world `.deb`).
3. Přenést stejný build do Workshop prostředí (YAML ve verzování).
4. Dokončit `compile_OpenSSL.sh`, doplnit chybějící `package_python.sh` a otestovat Python `.deb` na reálném N900.
5. Teprve potom portovat vlastní aplikace.

## 7. Otevřené otázky

- Rozhodnuto: primární cíl je Maemo 5 (Fremantle), armel, glibc 2.5.
- Které aplikace backportovat jako první?
- Kde je dnes dostupné zrcadlo Fremantle SDK a `-dev` balíčků?
- Instalovat CSSU na obě zařízení?
- Funguje binfmt/qemu-user uvnitř neprivilegovaného Workshop kontejneru?
- Aktuální obrazy VM na maedevu.maemo.org a jejich verze.
- Aktuální suite a mirror pro armhf chroot Maemo Leste.

## 8. Zdroje

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
