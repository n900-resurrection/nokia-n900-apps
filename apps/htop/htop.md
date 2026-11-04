# htop 3.5.3 na Maemo 5

Stav k 2026-11-04. Build a balení: [Makefile](Makefile) (`make htop` v kořeni, `make -C apps/htop <cil>`).
Balíček `htop3` se sestaví, **instalace na telefon zatím nezkoušena**.

## Build

- Upstream tag `3.5.3`, autotools, cross-build ve Workshopu (`apps/htop/build.sh`).
- ncursesw staticky (telefon má jen `libncurses5`), `--enable-unicode`, vypnuto hwloc, sensors, capabilities, delayacct.
- Jediná úprava kvůli glibc 2.5: chybí `O_CLOEXEC` (viz `scripts/maemo-compat.h`). Hlavička nesmí nic includovat.
- Prefix `/opt/htop3`. Výsledek: 394 kB po stripu, `NEEDED`: librt, libdl, libm, libc, nejvyšší symbol `GLIBC_2.4`.
- Na telefonu ověřeno: `--version`, spuštění s ptty a vykreslení rozhraní.

## Co je na telefonu už nainstalováno

- Balíček `htop 0.8.3-1maemo5`. `/usr/bin/htop` je jen obálka (skript), skutečná binárka je
  `/opt/maemo/usr/bin/htop`; s `--xterm` spouští `term-app-launcher`.
- Nastavení starého htopu: `~/.htoprc` (formát 0.8.3, `delay=15`).

## Měření výkonu (2026-11-04)

Postup: každá varianta 30 s v ptty přes `ssh -tt`, výstup do `/dev/null`, měřen čas procesoru (`user` + `sys`)
přes `time timeout -t 30 htop`. Každý běh s prázdným `HOME` (výchozí nastavení, aby se nepřepsal
`~/.htoprc`). Telefon v klidu (load 0,2; 160 procesů).

| Varianta | user | sys | celkem za 30 s | využití jádra |
|---|---|---|---|---|
| htop 0.8.3, výchozí (1,5 s) – běh 1 | 0,76 s | 1,17 s | 1,93 s | 6,4 % |
| htop 0.8.3, výchozí – běh 2 | 0,82 s | 1,16 s | 1,98 s | 6,6 % |
| htop 3.5.3, výchozí (1,5 s) – běh 1 | 1,35 s | 3,31 s | 4,67 s | 15,6 % |
| htop 3.5.3, výchozí – běh 2 | 1,52 s | 3,23 s | 4,74 s | 15,8 % |
| htop 0.8.3, `-d 50` (5 s) | 0,33 s | 0,40 s | 0,73 s | 2,4 % |
| htop 3.5.3, `-d 50` | 0,63 s | 1,31 s | 1,93 s | 6,4 % |

Závěry:

- Odhad „2× náročnější“ se potvrdil: **nový htop spotřebuje 2,4× víc času procesoru** (výchozí interval),
  a 2,7× při `-d 50`.
- Převážnou část navíc tvoří **systémový čas** (`sys` 2,8× víc, `user` 1,8× víc). Nový htop čte víc souborů
  v `/proc` na proces.
- **`-d 50` snižuje spotřebu nového htopu na úroveň starého při výchozím intervalu** (1,93 s vs 1,95 s).

Omezení měření: jeden telefon, 30 s, výstup do `/dev/null` (kreslení na skutečný terminál není započítáno),
výchozí nastavení obou verzí se liší (např. viditelná vlákna), zahrnuje start. Dva běhy výchozího nastavení
se liší do 2 %, ostatní jednou.

## Výchozí interval `-d 50`

Pořadí hledání nastavení v novém htopu (podle `Settings.c`, 3.5.3):

1. proměnná `HTOPRC` (celá cesta k souboru). Pokud je nastavena, **starý `~/.htoprc` se vůbec nečte ani nemaže**;
2. `~/.config/htop/htoprc` (nebo `$XDG_CONFIG_HOME/htop/htoprc`);
3. starý `~/.htoprc`. Nový htop ho **přečte, uloží do nového umístění a starý soubor SMAŽE**;
4. systémový `SYSCONFDIR/htoprc` (u nás `/opt/htop3/etc/htoprc`, předpoklad podle `--prefix`, **neověřeno**);
5. vestavěné výchozí hodnoty (`DEFAULT_DELAY` = 15, tedy 1,5 s).

Volby:

| Způsob | Poznámka |
|---|---|
| `delay=50` v htoprc (jednotka desetiny sekundy, rozsah 1 až 255) | funguje, ale nový htop při ukončení soubor přepisuje |
| Systémový `/opt/htop3/etc/htoprc` v balíčku | použije se jen když uživatel nemá vlastní config; na tomto telefonu má root starý `~/.htoprc`, takže by se přeskočil |
| **Obálka** `/usr/bin/htop3`: `HTOPRC=… exec /opt/htop3/bin/htop -d 50 "$@"` | **zvoleno** (viz níže): přepínač `-d` má přednost před configem a `HTOPRC` chrání starý `~/.htoprc` před smazáním |

`-d` přes příkazovou řádku má maximum 100 (10 s), v configu 255.

## Rizika a poznámky

- Spuštění nového htopu bez `HTOPRC` při existujícím `~/.htoprc` ho podle zdrojáků smaže po migraci.
  Na zařízení jsem to nepozoroval (starý soubor zůstal), ale je to chování zdrojáků.
- Systémový `htop` 0.8.3 se balíčkem `htop3` nemění. Návrat zpět: `make -C apps/htop remove`.

## Balíček `htop3`

Rozhodnuto (2026-11-04): **samostatný balíček `htop3`** vedle systémového `htop` 0.8.3, ne jeho náhrada.
Důvody: systémový balíček závisí na `term-app-launcher` a má vlastní spouštěč, nový htop je 2,4× náročnější
a s vlastním nastavením se hodí mít oba, a odinstalace je bez rizika pro systém.

| Co | Kde |
|---|---|
| binárka | `/opt/htop3/bin/htop` (ncursesw staticky) |
| obálka | `/usr/bin/htop3` (`HTOPRC=$HOME/.config/htop3/htoprc`, výchozí `-d 50` pokud není zadáno `-d`/`--delay`) |
| spouštěč | `/usr/share/applications/hildon/htop3.desktop` (`osso-xterm -e /usr/bin/htop3`, jako u WordGrinderu) |
| dokumentace | `/opt/htop3/share/doc/htop3/` (`COPYING`, `README.Maemo`), manuál v `/opt/htop3/share/man/man1/` |
| metadata | `Package: htop3`, `Section: user/system`, `Depends: libc6 (>= 2.5)`, `Architecture: armel` |

```bash
make htop                  # nebo: make -C apps/htop build
make -C apps/htop deb      # build/deb/htop3_3.5.3-1maemo1_armel.deb (215 kB)
make -C apps/htop info     # metadata a obsah
make -C apps/htop install  # zkopíruje a nainstaluje na N900 (dpkg -i), mění telefon
make -C apps/htop run      # spustí /usr/bin/htop3 přes ssh
```

Ověřeno: balíček se sestaví, má správná práva (755/644, `root:root`), formát gzip, a **obálka** se chová podle
očekávání (testováno lokálně s maketou místo htopu): bez argumentů přidá `-d 50`, s `-d 20`, `-d20`,
`--delay=30` nebo `--delay 30` ponechá zadané, respektuje vlastní `HTOPRC` a `XDG_CONFIG_HOME` a vytvoří
složku pro config.

**Neověřeno:** instalace na zařízení (`dpkg -i`, `dpkg -L`), spuštění z menu, Application Manager.
Binárka sama na telefonu běží (viz výše). Ikona v menu bude výchozí (`.desktop` nemá `Icon=`).
Licence: htop je GPL-2+, balíček obsahuje `COPYING` a odkaz na zdroj (upstream tag + naše úprava `scripts/maemo-compat.h`).
