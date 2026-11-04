# tty-clock 2.3 na Maemo 5

Stav k 2026-11-04. Build a balení: [Makefile](Makefile) (`make tty-clock` v kořeni, `make -C apps/tty-clock <cil>`).
Společné cíle a konvence jsou v [../../mk/app.mk](../../mk/app.mk).

Digitální hodiny v terminálu. Upstream: <https://github.com/xorg62/tty-clock> (BSD, tag `v2.3`).
V repozitářích Maemo 5 nebyly (ověřeno: extras, extras-testing, extras-devel, SDK).

## Build

- Jeden zdrojový soubor (`ttyclock.c`), překládá se přímo `scripts/maemo-gcc`, bez upstreamního Makefile.
- Používá obyčejný ncurses (žádné široké znaky), proto je slinkovaný **dynamicky se systémovým
  `libncurses5`**, který telefon už má (5.7, stejná verze jako v sysrootu).
- Výsledek: 18 kB, `NEEDED`: libncurses.so.5, libc.so.6, nejvyšší symbol `GLIBC_2.4`.

## Balíček `tty-clock`

- `Depends: libc6 (>= 2.5), libncurses5 (>= 5.7)`, `Section: user/utilities`, 10,5 kB.
- Soubory: `/opt/tty-clock/bin/tty-clock`, odkaz `/usr/bin/tty-clock`, manuál, `LICENSE` (BSD, vytažená
  z hlavičky `ttyclock.c`, upstream samostatný soubor nemá), spouštěč `tty-clock.desktop`.
- Spouštěč nemá argumenty (`osso-xterm -e` s argumenty není ověřené), hodiny tedy startují s výchozím
  nastavením. Pro sekundy a střed: `tty-clock -s -c` v terminálu.

## Ověřeno

- Překlad a `.deb` (metadata, obsah, práva).
- Na N900 (binárka v `/tmp`, po zkoušce smazaná): `ldd` najde `libncurses.so.5` v `/lib`, `tty-clock -v`,
  3 s běh na ptty s `-s -c` vykreslil rozhraní (985 B výstupu).

## Neověřeno

Instalace balíčku (`dpkg -i`), spuštění z menu, `man tty-clock`, chování po otočení displeje.
