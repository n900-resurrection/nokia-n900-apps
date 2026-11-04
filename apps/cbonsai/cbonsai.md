# cbonsai 1.4.2 na Maemo 5

Stav k 2026-11-04. Build a balení: [Makefile](Makefile) (`make cbonsai` v kořeni, `make -C apps/cbonsai <cil>`).
Společné cíle a konvence jsou v [../../mk/app.mk](../../mk/app.mk).

Generátor bonsají v terminálu. Upstream: <https://gitlab.com/jallbrit/cbonsai> (GPL-3, tag `v1.4.2`).
Projekt se přestěhoval z GitHubu na GitLab (`github.com/jallbrit/cbonsai` už neexistuje).
V repozitářích Maemo 5 nebyl (ověřeno: extras, extras-testing, extras-devel, SDK).

## Build

- Jeden zdrojový soubor (`cbonsai.c`). Upstreamní Makefile bere příznaky z `pkg-config`, který sysroot nemá,
  proto se překládá přímo. `-D_XOPEN_SOURCE_EXTENDED` zpřístupní deklarace širokých znaků.
- Kreslí široké znaky (`cchar_t`, `wchar_t`), potřebuje tedy **ncursesw**, které telefon nemá. `libncursesw`
  a `libpanelw` jsou proto **slinkované staticky** (stejně jako u WordGrinderu).
- Výsledek: 156 kB, `NEEDED`: jen libc.so.6, nejvyšší symbol `GLIBC_2.4`.
- Jediné varování překladače: ignorovaná návratová hodnota `strtold` (`-Wunused-result`), neškodné.
- Manuál se tvoří z `cbonsai.scd` nástrojem `scdoc`, který ve Workshopu není, takže balíček manuál nemá.

## Balíček `cbonsai`

- `Depends: libc6 (>= 2.5)`, `Section: user/other`, 95 kB.
- Soubory: `/opt/cbonsai/bin/cbonsai`, odkazy `/usr/bin/cbonsai` a `/usr/bin/cbonsai-live`, `LICENSE`, `README.md`,
  spouštěč.
- `cbonsai` bez přepínačů nakreslí jeden strom a skončí, okno terminálu by se tedy hned zavřelo. Spouštěč
  proto volá skript `cbonsai-live` (`cbonsai -l -i`: strom roste živě, jeden za druhým, `q` ukončí).

## Ověřeno

- Překlad a `.deb`.
- Na N900 (binárka v `/tmp`, po zkoušce smazaná): `ldd` (jen libc), `--help`, 3 s běh na ptty s `-l -s 7`
  vykreslil animaci (300 kB výstupu, růst stromu generuje hodně escape sekvencí).

## Neověřeno

Instalace balíčku, spuštění z menu přes `cbonsai-live`, výkon a plynulost na 600 MHz, Unicode znaky
v terminálu telefonu (závisí na fontu `osso-xterm`).
