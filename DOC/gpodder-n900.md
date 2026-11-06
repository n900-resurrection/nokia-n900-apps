# gPodder pro N900: zdrojové kódy a postup (2026-11-05)

**Na telefonu je** `gpodder 2.20.2-1` (Python 2.5, PyGTK, Hildon; autor Thomas Perl), předplatné jsou v `~/.config/gpodder` (3 kanály, `database.sqlite`, `channels.opml`).

## Zdrojové kódy (GitHub gpodder/gpodder)
| Co | Kde | Poznámka |
|---|---|---|
| gPodder pro Maemo 5 | značka `obsolete/maemo5` | verze **2.20.3-1** (2012-12-22), novější než na telefonu (2.20.2). Python 2.5, odpovídá `python-gtk2`/Hildon. Stažené do `build/src/gpodder-maemo5`. |
| Maemo 4 | značka `obsolete/maemo4` | pro N8x0, nezajímavé |
| Moderní verze | `master`, značka `3.11.5` (2024-12-19) | Python 3.7+, GUI GTK 3 (na N900 není), ale jádro a příkaz `gpo` jsou bez GUI. Větev `old/gtk2` je poslední GTK 2 kód. Stažené do `build/src/gpodder-master`. |
Závislosti 3.11.5 jsou čistý Python: `podcastparser`, `mygpoclient`, volitelně `dbus-python` a `PyGObject` (jen GUI a D-Bus). Podle Debianu Maemo platformy 3.x nepodporuje a dostávají jen verzi 2.20.x ([README](https://sources.debian.org/src/gpodder/2.20.1-1/README)).

## Balíček 2.20.3 (postaveno 2026-11-05)
`make -C apps/gpodder deb` stáhne zdroje značky `obsolete/maemo5` (commit `0bfdbc84`), složí strom jako `setup.py install` (4 Python balíčky, skripty, data, 23 překladů přes `msgfmt`, služba D-Bus)
a vyrobí `build/deb/gpodder_2.20.3-1maemo1_armel.deb` (628 kB, závislosti stejné jako původní balíček, `postinst` z upstreamu). Skutečným Pythonem 2.5 (z telefonu, pod qemu) prošla kontrola syntaxe všech modulů.
**Neinstalováno na telefon:** nahrazuje běžící gPodder 2.20.2. Před instalací je rozumné zálohovat `~/.config/gpodder` (kanály a databáze zůstanou, balíček se jich nedotýká).
Spuštění na PC (`make hildon-run PY2=1`) došlo až do konstruktoru okna, pak chybí služba `com.nokia.icd` (správce připojení Maemo); okno se na PC nevykreslilo.
`yt-dlp` a `podcastparser` + `mygpoclient` pro moderní jádro jsou ve Workshopu v `build/pylibs`.

## Co s tím
1. **Okamžitě:** aktualizovat na 2.20.3 (balíček je hotový, viz výše; podle changelogu opravy stahování z YouTube, bug 1665).
2. **Patchnutá varianta:** problémy 2.20.x jsou hlavně HTTPS (Python 2.5 má TLS 1.0, stejný problém jako u e-mailu) a YouTube. Řešení: stahování zprostředkovat přes `curl` (TLS 1.3, už na telefonu) nebo přes Python 3 a `yt-dlp` ([youtube-n900.md](youtube-n900.md)).
3. **Moderně:** jádro gPodderu 3.11 + `gpo` na našem Pythonu 3.11 (CLI, sync s gpodder.net) a vlastní Hildon GUI přes ctypes ([hildon-python3.md](hildon-python3.md)), seznam epizod stejně jako v mutt-hildon. Vyžaduje `podcastparser` a `mygpoclient` (`pip install`, čekám na povolení, viz výše; jinak vendorovat zdroje z git).
Audiobookshelf (LAN) lze číst stejným způsobem jako zdroj.
