# Hry k portu na N900 (rešerše, 2026-11-23)

Vychází ze seznamu hotového jiným nástrojem (text byl vložen do konverzace) a z toho, co umí náš build (Maemo 5, GCC 13 cross, glibc 2.5 se shimy, `maemo-g++`
pro C++17, SDL 1.2 v sysrootu, GTK 2.14/Hildon, ncurses 5.7). **Nic z toho není postavené ani vyzkoušené.** Co jsem nemohl ověřit, je označené **ověřit**
(webové vyhledávání nepřineslo spolehlivé zdroje, takže údaje o verzích SDL u jednotlivých projektů jsou z paměti).

## Co o telefonu a o našem prostředí platí (a vložený text to míjí)

- **SDL 2 nemáme.** Sysroot má jen SDL 1.2.13 (`libsdl1.2-dev`), `SDL_mixer`, `SDL_image` a `SDL_ttf` 1.2 jsou v indexu SDK, v našem mirroru zatím nejsou
  (přidají se samy při prvním použití, viz `make sysroot`). Většina současných verzí her chce SDL 2: **buď starší vydání na SDL 1.2, nebo napřed samostatná
  práce „SDL 2 pro Maemo 5“** (X11 a softwarový renderer bez GLES; touž překážku uvádí položka o Neverballu v `TODO.md`).
- **SDK nemá `libvorbis`, `libogg`, `physfs`, `lua`, `boost`, `openal`, ani hlavičky EGL/GLES** (ověřeno v indexu: `fetch_sysroot.py --list`). Hry s hudbou ve Vorbisu,
  Lua skripty nebo GLES si musí postavit závislosti samy (jako ostatní aplikace v `build/deps`); GLES hlavičky by přišly z katalogu Nokie (viz Neverball).
- **Už pro Maemo 5 existují** (z `TODO.md` a z Maemo wiki): `openttd`, `openjazz`, `wolf3d`, `opendune`, `frogatto`, `scummvm`, `freeciv`, `supertux`, `fheroes2`,
  `prboom`, `quake2`, `wesnoth` (1.6.x), roguelikes z extras-devel. Port starých verzí má smysl jen kvůli novější verzi nebo kvůli závislostem, které se
  dnes nedají doinstalovat; hry, které nikdo nepřeložil, mají přednost.
- **GLES na telefonu je 1.1/2.0 přes PowerVR SGX**, ale bez hlaviček v sysrootu a bez SDL 2 se 3D hry nedají přeložit; proto jsou níž.

## Oprava vloženého seznamu

| Tvrzení | Skutečnost |
|---|---|
| QuakeSpasm má softwarový renderer | Nemá, je jen OpenGL. Softwarový je **TyrQuake** (SW i GL) nebo `sdlquake`. Quake 1 má navíc smysl jen s GLES. |
| ioquake3 / OpenArena na N900 | Nereálné: 256 MB RAM, ~10 MB volných, Cortex-A8 600 MHz. Vynechat. |
| Chocolate Doom / PrBoom+ | Chocolate Doom 2.x je poslední na SDL 1.2, od 3.0 (2017) SDL 2. PrBoom+ jen ověřit. `prboom` už pro Maemo 5 existuje. |
| NXEngine-evo | Chce SDL 2 (+ `SDL_ttf`, `SDL_mixer`, libpng, libjpeg). Původní **NXEngine** (SDL 1.2) je lepší první krok. |
| Abuse „public domain“ | Zdroje SDL portu jsou public domain/GPL2/WTFPL (podle balíčkovačů), data shareware jsou volná; SDL 2 větev je fork, původní (0.8) je SDL 1.2. Číst licence v `COPYING`. |
| DevilutionX „chce SDL 2“ | Má `-DUSE_SDL1=ON` (SDL 1.2 pro slabé konzole), ale bez škálování a celé obrazovky. **Ověřit** u upstreamu, ne jen u forku. |
| OpenLara „běží na GBA“ | Běží tam jen vlastní GBA port; verze se SDL 2/GLES 2 chce EGL a data z originálu. Těžké. |
| ScummVM / OpenTTD: SDL 1.2 | Nelze potvrdit, od které verze SDL 1.2 vypadlo (u OpenTTD i ScummVM jde o paměť a fóra). **Ověřit** v `configure`/CMake před prací. |

## Priorita: hry, které pro Maemo 5 nikdo nepřeložil, mají přednost

Rozhodnutí 2026-11-23. Neexistuje úplný seznam balíčků Maemo 5 (Extras, extras-devel, Garage), proto se u každé hry **před prací** hledá na wiki a fórech maemo.org („<hra> maemo“,
„<hra> n900“) a v indexech repozitářů. Podle toho, co jsem našel nebo nenašel:
- **A. Nikdo nepřeložil (nenalezeno, ověřit):** DevilutionX, NXEngine-evo, CorsixTH, OpenLara, Brogue CE, C-Dogs SDL, Abuse, Simon Tatham's Puzzles, Chocolate Doom 3, TyrQuake.
- **B. Stará verze už je (vlastní překlad má smysl jen kvůli novější verzi):** ScummVM, OpenTTD, fheroes2, prboom, Wesnoth, supertux, wolf3d, quake2, NetHack a další roguelikes z extras-devel.
Pořadí práce: **SDL 2** (umožní celou skupinu A kromě her, které ho nepotřebují) → hry skupiny A podle rizika (tabulka níž) → B.

## Kandidáti, od nejlevnějšího

| # | Hra | Závislosti a data | Licence | Odhad | Poznámka |
|---|---|---|---|---|---|
| 1 ✓ | **Simon Tatham's Puzzles** (~40 logických her; **hotovo 2026-11-23, `apps/sgt-puzzles`**, GTK 2 front end funguje, potřeboval jen shimy `tgmath.h`, `GDK_KEY_*` a `gtk_widget_set_can_default`) | C, **GTK 2** (máme 2.14), CMake, `halibut` jen na dokumentaci (nepotřebné) | MIT | malé | Nepotřebuje SDL ani data. GTK 2 front end je v upstreamu (**ověřit**, že ho nová CMake ještě umí). Dotyk = klepnutí myší; pravé tlačítko nahradit klávesnicí nebo dlouhým stiskem. Lze zabalit jako Hildon okno. |
| 2 | **NetHack 3.7**, **Angband 4.2**, **Brogue CE** (konzolový build) | C, ncurses 5.7 (máme) | NGPL / GPL2 / AGPL | malé | Terminál 80×24 s fyzickou klávesnicí je pro roguelike ideální. NetHack a Angband v extras-devel už byly (staré verze). Brogue CE: ověřit volbu bez SDL (`TERMINAL=YES`). DCSS je těžká (C++, Lua, SQLite) – až později. |
| 3 | **Abuse** (SDL 1.2 větev 0.8) | C++, SDL 1.2, `SDL_mixer`; data shareware jsou volná | PD / GPL | střední | Bez SDL 2. Ověřit, zda se dá starší zdroj 0.8 přeložit s GCC 13 (C++ z roku 2000). |
| 4 | **NXEngine** (původní, SDL 1.2) | C++, SDL 1.2, `SDL_mixer`; **hru Cave Story (freeware) dodá hráč** | GPL | střední | NXEngine-evo čeká na SDL 2. Nejmenší riziko mezi akčními hrami. |
| 5 | **C-Dogs SDL** (starší větev na SDL 1.2) | C, SDL 1.2, `SDL_mixer` | GPL2 | střední | Novější verze chtějí SDL 2: **ověřit**, kterou řadu lze ještě na SDL 1.2. |
| 6 | **Commander Genius** (Keen 1–6, starší řada) | C++, SDL 1.2 | GPL2 | střední | 3.x je SDL 2 (**ověřit**). Data: shareware Keen 1 je volný. |
| 7 | **ScummVM** novější než Maemo 5 verze | C++11, SDL 1.2 (**ověřit**) | GPL2 | velké | Už existuje (stará), smysl má jen kvůli dalším enginům a hrám. Zdarma: *Beneath a Steel Sky*, *Flight of the Amazon Queen*. Binárka je velká, `/opt` je jen 57 MB, instalace do `/home/opt`. |
| 8 | **OpenTTD** novější | C++, SDL 1.2 (**ověřit**), OpenGFX/OpenSFX (volné) | GPL2 | velké | Už existuje (`openttd`). |
| 9 | **DevilutionX** | C++20, `-DUSE_SDL1=ON`, data z Diabla (shareware `spawn.mpq` volný) | ověřit | velké | RAM je na hraně, **ověřit** velikost za běhu. |

## SDL 2 pro Maemo 5: zkouška 2026-11-23 (jde to)

SDL 2.30.11 se přeložila `scripts/maemo-gcc` proti sysrootu (statická knihovna, 9,8 MB, bez GL/GLES/Vulkanu/joysticku/D-Bus/udev) a malý program ji
spustil v emulátoru (qemu-user + Xvfb 800×480×16, glibc 2.5 ze sysrootu): `video=x11`, okno 800×480, povrch okna `RGB565`, kreslení a `SDL_UpdateWindowSurface` fungují.
Co se při tom zjistilo:
- **Joystick vypnout** (`--disable-joystick`): hlavičky jádra 2.6.28 nemají `input_absinfo.resolution`; telefon joystick stejně nepotřebuje.
- **Zvuk zatím není ověřený:** přeložil se jen ovladač `dummy` (hlavičky ALSA a PulseAudio nejsou v našem sysrootu; `libasound2-dev` a `libpulse-dev` 0.9.15 v indexu SDK jsou a přidají se do mirroru). Zvuk SDL 1.2 na telefonu funguje, takže ALSA (`default`) nebo PulseAudio se zkusí na telefonu.
- **X11 se načítá za běhu** (`x11(dynamic)`), volitelná rozšíření (XRandr, Xcursor, XInput2) jdou vypnout nebo dostat z `-dev` balíčků SDK.
- V emulátoru je potřeba `LC_ALL=C` (jako u ostatních programů).
- **Zbývá na telefonu:** celá obrazovka pod hildon-desktop (`_NET_WM_STATE_FULLSCREEN`), vstup z klávesnice a dotyku, skutečná rychlost (povrch okna je přímý, `SDL_Renderer` přidá kopii: na Cortex-A8 měřit) a zvuk.
- Balení: SDL 2 a `SDL2_mixer/image/ttf` jako vlastní balíček (`/opt/sdl2`) nebo staticky do každé hry (jako ostatní aplikace); GLES se tím neřeší (Neverball, OpenLara by potřebovaly EGL).
**Hotovo (2026-11-23): `apps/sdl2`**, balíček `libsdl2` 2.30.11-1maemo1 (487 kB, `/opt/sdl2/lib`, nejvyšší symbol glibc 2.4): ovladače videa x11, offscreen, dummy; zvuku ALSA, PulseAudio, dummy;
nástroj `sdl2-info` (`--window` kreslí, `--beep` hraje tón); 8 testů v emulátoru (`make emu-test APP=sdl2`), okno 800×480 RGB565 pod Xvfb. Hlavičky pro překlad her jsou v `build/out/sdl2-<verze>/root/opt/sdl2`
(`MAEMO_DEPS`, `-Wl,-rpath,/opt/sdl2/lib`). Hotové jsou i `apps/sdl2-image` 2.8.8 (PNG/JPEG přes stb_image, GIF, BMP, XPM, LBM, QOI, XCF; bez TIFF, WebP, AVIF, JXL, SVG), `apps/sdl2-mixer` 2.8.1 (WAV, AIFF, VOC, Ogg přes stb_vorbis, MP3 přes minimp3,
FLAC přes dr_flac; bez MOD, MIDI, Opus, WavPack) a `apps/sdl2-ttf` 2.24.0 (FreeType z tarballu, bez HarfBuzz), všechny bez cizích knihoven a s `-Wl,-rpath,/opt/sdl2/lib`; balíčky `libsdl2-image/-mixer/-ttf` závisí na `libsdl2 (>= 2.30)`.
Zkouška v emulátoru: načtení PNG a JPG, WAV a inicializace Ogg/MP3/FLAC (dummy zvuk), text s českou diakritikou. Zbývá zkouška na telefonu a případně MIDI (timidity + zvukový font nebo fluidsynth).

## Čeká na „SDL 2 pro Maemo 5“ (jedna práce odemkne víc her)

NXEngine-evo, OpenLara, fheroes2 (aktuální), Chocolate Doom 3, CorsixTH, DevilutionX (bez `USE_SDL1`), Neverball 1.6, Wesnoth ≥ 1.15 (to navíc potřebuje Boost a hodně RAM).
Zadání: SDL 2.0.x, X11 videodriver a softwarový renderer, ALSA/PulseAudio zvuk, shimy pro glibc 2.5; kontrola proti `apps/vlak` a `apps/nplay`.

## Nedoporučeno

- **ioquake3 / OpenArena / EDuke32 (Polymost)**: výkon a paměť.
- **Hedgewars** (Haskell + Free Pascal), **Warmux** (opuštěný, mnoho knihoven), **Stratagus/Wargus** (Lua, tolua++, převod dat Warcraftu II), **VCMI**.
- **OpenXcom** je hotový na druhém počítači (zapisuje se tam); data originálu dodá hráč.

## Poznámka k datům

Nic autorského nedodávat: balíčky obsahují jen engine, hráč přidá data (Doom: Freedoom, Keen: shareware, Cave Story: freeware, Diablo: shareware nebo vlastní disk).
