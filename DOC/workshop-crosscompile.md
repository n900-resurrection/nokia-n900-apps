# Cross-kompilace pro Maemo 5 ve Workshopu

Stav k 2026-11-03. Obecný kontext je v [../README.md](../README.md).
Definice prostředí: [../.workshop/n900.yaml](../.workshop/n900.yaml), sysroot skript: [../scripts/fetch_sysroot.py](../scripts/fetch_sysroot.py).

## 1. Syntaxe Workshopu (co je ověřené)

Zjištěno z `workshop --help` na tomto stroji (workshop 0.9.9) a z oficiálního Java tutoriálu a blogu.

### Instalace

```bash
sudo snap install --channel=6/stable lxd
sudo snap install --classic workshop
```

Na tomto stroji je LXD nainstalované a inicializované (`lxd init`, výchozí hodnoty: ZFS pool 30 GiB, bridge `lxdbr0`). Workshop `n900` je spuštěný (`workshop launch n900`).

Zjištěné vlastnosti prostředí (2026-11-03):

- Uživatel v kontejneru je `workshop` (uid 1000), má `sudo` bez hesla a přístup k internetu. Projekt je v `/project`.
- **`workshop exec` mi bez terminálu nevypisuje stdout** (rc 0, výstup prázdný). Z nástroje bez TTY proto výstup přesměrovávám do souboru v `/project`. Při práci z vlastního terminálu to není problém.
- `workshop run n900 -- toolchain` mi po dokončení instalace **zůstal viset** (akce zůstala ve stavu Doing). Balíčky byly přitom nainstalované. **[ověřit]** v interaktivním terminálu, jestli se to chová stejně.

### Definiční soubor `.workshop/<jmeno>.yaml`

```yaml
name: n900
base: ubuntu@24.04          # podporováno: ubuntu@22.04, 24.04, 26.04
sdks:                       # volitelné
- name: openjdk
  channel: 21/stable
slots:                      # rozhraní (např. tunnel na host)
  app:
    interface: tunnel
    endpoint: localhost:8080
plugs: {}
actions:                    # pojmenované příkazy pro `workshop run`
  build: mvn clean package
```

`workshop init n900` (bez SDK) vytvořil validní minimální soubor se `name` a `base`. Další poznatky:

- Runtime je `lxd-container` (výchozí) nebo `lxd-vm`.
- Projektový adresář se mountuje do kontejneru jako **`/project`** (podle blogu o Claude Code).
- `/home` v kontejneru patří uživateli `workshop`, ne hostiteli.
- Síť přes bridge `workshopbr0`. Pokud je na hostiteli Docker, jeho `FORWARD DROP` může blokovat provoz kontejneru (viz blog, `nft` pravidla do `DOCKER-USER`).

### Příkazy

| Příkaz | Význam |
|---|---|
| `workshop init <NAME> [--sdks a,b/ch] [--base ubuntu@24.04] [--runtime lxd-vm]` | vytvoří definici |
| `workshop launch [NAME]` | postaví a spustí |
| `workshop info` / `list` | stav |
| `workshop exec <NAME> -- <příkaz>` | jednorázový příkaz |
| `workshop shell [NAME]` | interaktivní shell |
| `workshop actions` / `workshop run <NAME> -- <akce>` | pojmenované akce z YAML |
| `workshop refresh` | použije změny v definici |
| `workshop stop` / `start` / `remove` / `restore` | životní cyklus |
| `workshop connect` / `disconnect` / `connections` | plugy a sloty |
| `workshop remount` | změna zdroje mount pluga |
| `workshop sketch-sdk` | interaktivní „skicovací“ SDK (editor), `--eject` uloží do `.workshop/` |
| `workshop changes`, `tasks <ID>`, `warnings`, `okay` | historie a varování |
| `sdk find <text>`, `sdk info <sdk>` | hledání SDK v Store |

### SDK

- `sdk find gcc/arm/cross` nenašel žádný SDK pro `arm-linux-gnueabi` ani pro Maemo. Existují jen jiné (např. `zephyr*`, `go`, `node`, `uv`).
- Vlastní SDK: nástroj `sdkcraft` (`sdkcraft init`, `pack`, `try`), definice `sdkcraft.yaml`, hooky jako shell skripty v `hooks/`. Podrobnosti viz [canonical/sdkcraft](https://github.com/canonical/sdkcraft) a [How to build an SDK](https://ubuntu.com/workshop/docs/how-to/develop-sdks/build-an-sdk/). **[ověřit]** přesný formát.
- Pro náš účel stačí zatím prosté `workshop exec` + akce v YAML. Případně `workshop sketch-sdk --eject --name n900-tools` pro trvalý in-project SDK.

## 2. Postup

```bash
cd /home/pytel/Git/N900
sudo snap install --channel=6/stable lxd && sudo lxd init   # jednorázově (hotovo)
workshop launch n900
workshop run n900 -- toolchain     # gcc-arm-linux-gnueabi (armel) + qemu-user
workshop run n900 -- sysroot       # sysroot z Fremantle SDK (111 balíčků, 91 MB rozbaleno)
workshop run n900 -- hello         # přeloží hello.c a spustí ho pod qemu proti sysrootu
```

Před `launch` zkontroluj `workshop info` a `workshop warnings`.

## 3. Sysroot

`scripts/fetch_sysroot.py` (jen stdlib Pythonu, spouští se v kontejneru i na hostiteli):

- stáhne `Packages` ze `sdk/{free,non-free}` na `maemo.plan9.de`,
- vybere nejnovější verzi každého balíčku a vyřeší `Depends`,
- stáhne jen potřebné `.deb` (pauza 0,3 s mezi soubory), rozbalí přes `dpkg-deb -x` do `./sysroot`.

```bash
python3 scripts/fetch_sysroot.py --dry-run             # plán (výchozí sada: 111 balíčků, ~31 MB)
python3 scripts/fetch_sysroot.py libncursesw5-dev      # jen konkrétní balíčky
python3 scripts/fetch_sysroot.py --list ncurses        # hledání v indexu
```

Ověřeno (2026-11-03):

- Výchozí sada ve Workshopu: 111 balíčků, sysroot má 91 MB.
- `libc-2.5.so` je `ELF 32-bit LSB shared object, ARM, EABI5`, interpreter `/lib/ld-linux.so.3`.
- Hlavičky ncurses a `libc.a` jsou v sysrootu, hlavičky jádra jsou verze 2.6.28.

### Překlad: `scripts/maemo-gcc`

Přímé `arm-linux-gnueabi-gcc --sysroot=...` **nestačí**, našel jsem dva problémy:

1. Ubuntu cross-gcc 13.3 hledá svoji vlastní libc (glibc 2.39) v `/usr/arm-linux-gnueabi/lib` **dřív** než sysroot. Binárka pak chtěla `GLIBC_2.34` (`__libc_start_main`), která na Maemo 5 není.
2. S objekty z glibc 2.5 padá `ld.bfd` 2.42 na `assertion fail ../../bfd/elf32-arm.c:14837`.

Řešení je ve wrapperu [../scripts/maemo-gcc](../scripts/maemo-gcc): vynutí cesty `-B/-L` a `-nostdinc -isystem` na sysroot a použije `-fuse-ld=gold`. Výsledek `src/hello.c`:

- `ELF 32-bit LSB executable, ARM, EABI5`, interpreter `/lib/ld-linux.so.3`, kernel 2.6.8,
- ARMv7 s NEON (`Tag_CPU_arch: v7`, `Tag_Advanced_SIMD_arch: NEONv1`),
- nejvyšší symbol `GLIBC_2.4`,
- **spuštěno pod `qemu-arm -L /project/sysroot build/hello`** (qemu-user), vypsalo `Hello from Maemo 5 (armel, glibc 2.5)`.

Tím je ověřeno linkování proti glibc 2.5, ne chování na skutečném N900. Wrapper je jen pro C.

### Dostupné verze v SDK (zjištěno z indexu)

| Knihovna | Verze |
|---|---|
| glibc | 2.5.1 (eglibc) |
| libstdc++6 / GCC | 4.2.1 |
| ncurses, ncursesw | 5.7+20081213 |
| zlib | 1.2.3 |
| **OpenSSL** | **0.9.8n** (ne 1.1.1, tedy `ssl` modul Pythonu 3.11 bez vlastního OpenSSL nepůjde) |
| GTK2 | 2.14.7 |
| glib | 2.20.3 |
| SDL | 1.2.13 |
| hildon | 2.2.3 |
| readline | 5.2 |

## 4. Poznámky a rizika

- `libc.so` je linkerový skript s absolutními cestami, vždy kompiluj s `--sysroot=/project/sysroot`.
- ABI: armel, `-march=armv7-a -mfpu=neon -mfloat-abi=softfp` (v binárce vyšlo `VFPv3`, `NEONv1`). **[ověřit]** na zařízení, hlavně `softfp` a `--hash-style=both`.
- Toolchain je GCC 13.3 z Ubuntu 24.04. Jednoduchý C kód odkazuje jen na `GLIBC_2.4`, ale složitější kód (vlákna, `stat`, C++) může vyžadovat novější symboly. Kontrolovat: `arm-linux-gnueabi-objdump -T bin | grep GLIBC`.
- C++: `maemo-gcc` s `-nostdinc` pro C++ nestačí (chybí hlavičky libstdc++). Připravit `maemo-g++` a slinkovat libstdc++ staticky (`-static-libstdc++ -static-libgcc`). **[ověřit]**
- `qemu-arm -L /project/sysroot` ověří jen linkování a základní běh, ne chování jádra 2.6.28 ani grafiku.
- Sysroot a `downloads/` jsou v `.gitignore`, jsou obnovitelné skriptem.
- Mirror `maemo.plan9.de` je snapshot z roku 2017. Dlouhodobě patří do vlastního mirroru, viz [mirror.md](mirror.md).
- Skript používá stahování jen po jednom souboru, aby nezatěžoval cizí server.

## 5. Zdroje

- [Workshop dokumentace](https://ubuntu.com/workshop/docs/)
- [Java Workshop SDKs tutoriál](https://ubuntu.com/developers/docs/tutorials/java-advanced/java-workshop-sdks/)
- [Claude Code ve Workshopu (Classmethod)](https://dev.classmethod.jp/en/articles/ubuntu-workshop-claude-code-sandbox/)
- [canonical/sdkcraft](https://github.com/canonical/sdkcraft)
- [SDK concepts](https://ubuntu.com/workshop/docs/explanation/sdks/concepts/)

## Sestavování balíčků přes make (2026-11-06)
- `make debs` projde `apps/*` a sestaví jen zastaralé `.deb` (razítka v `build/stamps`); `make debs APP="curl git"` vybere aplikace, `INSTALL=1` je i nainstaluje, `make -n debs` ukáže plán.
- `make <app> ACTION=deb` volá jiný cíl aplikace (výchozí je `build`). Cíle aplikací se generují z `apps/*/Makefile`.
- `DEPS := openssl curl` v `apps/<app>/Makefile`: závislosti se sestaví napřed a jejich přestavba způsobí přestavbu aplikace.
- Akce Workshopu `toolchain` obsahuje všechny balíky apt, které skripty používají, akce `pylibs` stáhne knihovny yt-dlp a gPodderu 3 do `build/pylibs`.
