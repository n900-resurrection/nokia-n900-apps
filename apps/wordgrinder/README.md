# WordGrinder pro Maemo 5

Konzolový textový procesor ([upstream](https://github.com/davidgiven/wordgrinder), MIT) přeložený pro N900
(armel, glibc 2.5). Rozbor a deník: [../../DOC/wordgrinder.md](../../DOC/wordgrinder.md).

## Soubory

| Soubor | K čemu |
|---|---|
| `Makefile` | vstupní bod: `build`, `deb`, `info`, `push`, `install`, `remove`, `run`, `clean` |
| `build.sh` | cross-build ve Workshopu (stáhne upstream tag, hostitelská Lua, ncursesw staticky) |
| `package.sh` | zabalí výsledek do `.deb` (`/opt/wordgrinder`, odkaz `/usr/bin/wordgrinder`, spouštěč) |

## Použití

```bash
cd apps/wordgrinder      # nebo make -C apps/wordgrinder <cil>
make                     # nápověda
make build               # build/out/wordgrinder-0.8/wordgrinder
make deb                 # build/deb/wordgrinder_0.8-1maemo1_armel.deb
make info                # metadata a obsah balíčku
make install             # zkopíruje na N900 a nainstaluje (dpkg -i), mění telefon
make run                 # spustí na telefonu přes ssh (TERM=xterm)
make remove              # dpkg -r
```

Jiná verze upstreamu: `make build deb VERSION=0.8` (tag musí existovat). Nový build jiné verze zatím není
zkoušený, ověřeno je jen 0.8.

## Stav

- `build`: ověřeno (binárka běží na N900, `--help` a převod `txt → html`).
- `deb`: balíček se vytvoří a má správná práva i formát. **Ověřeno na N900 (2026-11-04):** instalace,
  `dpkg -L` (všechny soubory na místě), `ldd` (jen libz, libm, libc), spuštění ze spouštěče v menu a z terminálu.
- Neověřeno: instalace z Application Manageru (ne přes `dpkg`), zobrazení v kategorii *Office*, vlastní ikona
  (`.desktop` nemá `Icon=`). Viz [../../TODO.md](../../TODO.md).
