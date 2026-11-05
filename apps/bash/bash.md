# Bash 5.3 pro Maemo 5

Balíček `bash5`, vedle systémového bashe 3.2. Nic nepřepisuje: `/bin/bash` zůstává.

## Sestavení a instalace
```sh
make -C apps/bash build      # překlad ve Workshopu (vždy)
make -C apps/bash deb        # balíček, když je build starší než zdroje, přeloží se sám
make -C apps/bash install    # deb, scp a dpkg -i na telefon
```
Výstup: `build/deb/bash5_5.3-1maemo1_armel.deb`. Instaluje do `/opt/bash5`, odkaz `/usr/bin/bash5`.

## Jak poznat, který bash běží
```sh
echo $BASH_VERSION        # verze shellu, ve kterém sedíš (5.3.0(1)-release)
readlink /proc/$$/exe     # skutečná binárka (/opt/bash5/bin/bash)
bash --version            # první bash v PATH, nemusí to být ten, ve kterém jsi
```
Systémový je 3.2.33 (`/bin/bash`), nový se spouští jako `bash5`.

## Používání
- Interaktivně: `bash5`. Skript: `#!/usr/bin/bash5`.
- Jako přihlašovací shell: přidat `/usr/bin/bash5` do `/etc/shells` a změnit shell uživatele. **Neověřeno.**
  Dokud to nezkusíš s otevřeným druhým spojením (SSH), nech `/bin/sh` / `/bin/bash`, ať se nezamkneš.
- Prompt: `bash5-5.3#` (výchozí, bez `~/.bashrc`).

## Technické poznámky
- Dynamicky proti glibc 2.5 a systémovému `libncurses5`, readline je vestavěný (z archivů v build adresáři;
  wrapper `maemo-gcc` dává sysroot dřív než lokální `-L`, proto se archivy musí zadat explicitně, viz `build.sh`).
- Bez NLS (nejsou gettext ani locale). Hodnoty `bash_cv_*` jsou předvyplněné, protože configure při cross-kompilaci nic nespustí.
- Pomalý: smyčka `for ((i=0;i<200000;i++)); do :; done` trvá 25 s (cca 8 000 iterací za sekundu).

## Testy
`make -C apps/bash test` ([test.sh](test.sh), 17 testů funkcí Bashe 5). Souhra s BusyBoxem je v testech busyboxu.
Výsledek 2026-11-05: 17 prošlo, 0 selhalo. Interaktivní readline (historie šipkou nahoru) ověřen přes `ssh -tt`.
Neověřeno: UTF-8 (chybí locale), přihlašovací shell, dlouhý provoz.
