# cmatrix 2.0 na Maemo 5

Stav k 2026-11-04. Build a balení: [Makefile](Makefile) (`make cmatrix` v kořeni, `make -C apps/cmatrix <cil>`).
Společné cíle a konvence jsou v [../../mk/app.mk](../../mk/app.mk).

Padající znaky jako v Matrixu. Upstream: <https://github.com/abishekvashok/cmatrix> (GPL-3, tag `v2.0`).
V repozitářích Maemo 5 nebyl (ověřeno: extras, extras-testing, extras-devel, SDK).

## Build

- Jeden zdrojový soubor (`cmatrix.c`). Makra, která by jinak zjistil CMake nebo `configure`, jsou v `build.sh`
  zapsaná napřímo (`HAVE_NCURSES_H`, `HAVE_USE_DEFAULT_COLORS`, `HAVE_RESIZETERM`, `HAVE_WRESIZE`, …).
  ncurses 5.7 všechny tři funkce má.
- Bez podpory konzolových fontů (`setfont`/`consolechars`), na Maemo 5 nejsou.
- Obyčejný ncurses, proto **dynamicky se systémovým `libncurses5`**.
- Výsledek: 14 kB, `NEEDED`: libncurses.so.5, libc.so.6, nejvyšší symbol `GLIBC_2.4`.

## Balíček `cmatrix`

- `Depends: libc6 (>= 2.5), libncurses5 (>= 5.7)`, `Section: user/other`, 22 kB.
- Soubory: `/opt/cmatrix/bin/cmatrix`, odkaz `/usr/bin/cmatrix`, manuál, `COPYING` (GPL-3), spouštěč.
- Spuštění z menu bez argumentů. `q` ukončí.

## Ověřeno

- Překlad a `.deb`.
- Na N900 (binárka v `/tmp`, po zkoušce smazaná): `ldd`, `cmatrix -V` (`CMatrix version 2.0`), 3 s běh
  na ptty s `-b` vykreslil animaci (140 kB výstupu).

## Neověřeno

Instalace balíčku, spuštění z menu, `man cmatrix`, `-s` (spořič) a barvy na displeji N900,
výkon při plné obrazovce.
