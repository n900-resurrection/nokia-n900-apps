# WordGrinder: backport na Maemo 5

Stav k 2026-11-03. Návrh, zatím nic nebylo sestaveno ani testováno.
Obecný kontext je v [../README.md](../README.md).

## O aplikaci

- Konzolový, Unicode-aware textový procesor, autor David Given.
- Repozitář: <https://github.com/davidgiven/wordgrinder>
- Aktuální verze: **0.9** (2025-01-22). Licence MIT (vložené komponenty MIT, BSD, public domain, SIL OFL u fontu).
- Pro N900 jsem nenašel žádný existující port pro Fremantle.
- Na postmarketOS už je zkoušený: [pmos_wordgrinder.md](https://github.com/elPytel/nokia-n900-notes/blob/main/doc/pmos_wordgrinder.md) (balík `wordgrinder-0.8-r2` z Alpine 3.22). Ovládání přes **Esc**, na klávesnici N900 `Shift + modrá šipka + Backspace`.
- Poznámka k verzím: Alpine má **0.8**, Luau přišlo až v **0.9**. Verze 0.8 je tedy první rozumný cíl backportu. **[ověřit]** jaký interpret 0.8 používá.

## Proč je to dobrý první kandidát

- Konzolová aplikace, bez Hildon a GTK.
- Většina závislostí je přibalená ve zdrojácích (Luau, MiniZip, cmark, fmt, stb, clip, xpattern, SCOWL).
- Na N900 se s HW klávesnicí dobře používá.

## Závislosti

| Závislost | Poznámka |
|---|---|
| ncursesw | Wide-character curses. **[ověřit]**, zda je na Maemo 5 k dispozici, jinak sestavit staticky. |
| zlib | Běžně dostupná. |
| Ninja | Jen na build hostiteli. |
| GLFW, OpenGL | Jen pro GUI frontend, **nepotřebujeme**. |

## Rizika

1. **Luau (C++)** v 0.9 nahradilo Lua. GCC 4.2 z Maemo 5 SDK to nezvládne, je potřeba moderní cross-compiler.
2. **libstdc++ a glibc 2.5:** moderní runtime může vyžadovat novější symboly. Řešení: statické slinkování (`-static-libstdc++ -static-libgcc`), případně celé statické linkování. Zjistí se až spuštěním na zařízení.
3. **Terminál:** potřebuje UTF-8 a dobrý font. Upstream uvádí, že fungují gnome-terminal, konsole, xterm a rxvt-unicode, ale ne rxvt a linuxová konzole. **[ověřit]** chování terminálu na N900.
4. **Paměť:** 256 MB RAM, hlídat velikost binárky a SCOWL slovníku.

## Postup

1. Zkusit starší verzi s Lua 5.3 (řada 0.7 / 0.8). Přesnou verzi dohledat v historii releasů. **[ověřit]**
2. Postavit pro armel (`arm-linux-gnueabi`), `-march=armv7-a -mfpu=neon -mfloat-abi=softfp`. **[ověřit]** flagy proti SDK.
3. Ověřit na N900: `file`, `ldd`, spuštění, UTF-8 vstup.
4. Zkusit 0.9 s Luau a statickým slinkováním.
5. Zabalit jako `.deb` (armel), nainstalovat přes `dpkg -i`.

## Build (návrh, neověřeno)

```bash
git clone https://github.com/davidgiven/wordgrinder
cd wordgrinder
# armel cross-build; přesné proměnné a konfiguraci doplnit podle jejich Makefile / configure
```

Upstream: `make` detekuje konfiguraci, `PREFIX=/usr/local ./configure` pro vlastní prefix. Podporu cross-kompilace (CC/CXX, sysroot) je potřeba dohledat v jejich build souborech. **[ověřit]**

## Deník

- **2026-11-04: WordGrinder 0.8 přeložen a spuštěn na N900.** Skript [../apps/wordgrinder/build.sh](../apps/wordgrinder/build.sh)
  (`make wordgrinder`). 0.8 používá přibalenou **Lua 5.1** (ne Luau), build přes `Makefile` + `ninja` + Lua skript `build.lua`.
  Výsledek: ELF ARM EABI5, 681 kB po stripu, `NEEDED`: libz.so.1, libm.so.6, libc.so.6, nejvyšší symbol `GLIBC_2.4`.
  Na telefonu ověřeno: `--help` a `--convert t.txt t.html` (Lua engine i export). **Interaktivní UI (curses) zatím
  nevyzkoušeno** – spustit v terminálu telefonu: `TERM=xterm /home/user/apps/wordgrinder`.
- Co se muselo řešit a proč: viz [packaging.md](packaging.md), sekce 1 (ncursesw staticky, hostitelská Lua,
  `-fgnu89-inline`, relativní symlinky ve sysrootu, strip).
- Otevřené: UTF-8 vstup z hardwarové klávesnice, výchozí ovládání (Esc = `Shift + modrá šipka + Backspace`), velikost
  slovníku/šablon, práce s terminfo (`TERM=xterm`, `xterm-256color` na telefonu chybí).
