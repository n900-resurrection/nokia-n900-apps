# sfeed 2.4 (RSS/Atom a podcasty v terminálu) pro Maemo 5

Sada malých nástrojů: `sfeed` převede RSS/Atom na prostý tabulátorový formát, `sfeed_curses` je čtečka, `sfeed_update`
stahuje kanály přes **curl** (TLS 1.3, balíček `curl`). Žádné další závislosti (jen `libncurses5` zařízení).

```sh
make -C apps/sfeed install    # build (když je zastaralý), deb, scp, dpkg -i
make -C apps/sfeed test       # 11 testů na telefonu (parsování RSS, enclosure, stažení kanálu přes TLS)
sfeed-reader                  # na telefonu: aktualizuje kanály a otevře čtečku (ikona "Feeds" v menu)
```

## Použití
- První spuštění `sfeed-reader` vytvoří `~/.sfeed/sfeedrc` z příkladu (`/opt/sfeed/share/doc/sfeed/sfeedrc.example`). Přidej kanály řádkem
  `feed "jméno" "https://adresa/rss.xml"`. Pozor: přes `ssh n900` jsi root, takže `~` je `/root`.
- **Podcasty** jsou obyčejné RSS kanály. Odkaz na audio je v 8. sloupci formátu sfeed (enclosure), takže jde stáhnout
  např. `sfeed ... | cut -f8`. Pomocné stahování epizod a přehrávání dojde se zvukovými nástroji (fáze 4 roadmapy).
- Ovládání čtečky: viz `?` v `sfeed_curses` (j/k pohyb, Enter otevře odkaz přes `$SFEED_PLUMBER`, `m` označí přečtené).

## Technické poznámky
- Upstream Makefile nastavuje `_XOPEN_SOURCE=700`, glibc 2.5 to nezná a pak nedefinuje `ssize_t` v `<stdio.h>`; build proto přidává
  `-D_GNU_SOURCE -include sys/types.h`.
- Ověřeno 2026-11-05: parsování RSS s enclosure, `sfeed_plain`, stažení `https://codemadness.org/atom.xml` přes curl.
  Neověřeno: ovládání `sfeed_curses` na displeji telefonu, `sfeed_update` s mnoha kanály (rychlost), kanály s jinou znakovou sadou.
