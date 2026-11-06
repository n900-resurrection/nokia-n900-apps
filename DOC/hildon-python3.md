# Hildon GUI z Pythonu 3 a zkoušení na PC

## Jde to? Ano, přes ctypes
Ověřeno 2026-11-05: Python 3.11 (balíček `python3.11`, revize 2maemo1) otevře okno Hildon (`HildonStackableWindow`, `HildonButton`)
a obsluhuje signály. Nativní vazby pro Python 3 totiž neexistují:
- **PyGTK** (`python-gtk2`, `python2.5-hildon`, na tom běží mutt-hildon) je jen pro Python 2,
- **PyGObject** potřebuje GObject Introspection a typelib pro GTK 3/4, GTK 2 a Hildon je nemají,
- zbývá **ctypes** (volání `libgtk-x11-2.0.so.0`, `libhildon-1.so.0`, `libgobject-2.0.so.0` přímo) nebo vlastní rozšíření v C.

ctypes stačí na vše, co aplikace potřebuje: signály jsou zpětná volání (`CFUNCTYPE`), časovače `g_timeout_add`. Příklad: [src/python3/hildon/proof.py](../src/python3/hildon/proof.py).
Cena: nejsou tam třídy, každé volání se píše ručně (typy argumentů a návratové hodnoty, `restype = c_void_p` u konstruktorů widgetů).
Rozumný další krok je malá vrstva (`hildonlite.py`) s třídami Window, Button, Label, Box, PannableArea, TextView, AppMenu a EntryCompletion.

## Spuštění GUI na PC (bez telefonu)
Princip: ARM Python (3.11 z `make python3`, nebo **Python 2.5 s PyGTK a Hildon z telefonu**) běží pod `qemu-arm` s **těmi samými knihovnami GTK 2.14 a Hildon 2.2**,
obraz jde na virtuální obrazovku Xvfb 800x480 uvnitř Workshopu. Vzhled je shodný s telefonem (motiv `beta`, písmo Nokia Sans).
```bash
make hildon-overlay                      # jednou (~100 MB): motiv, písma, ikony, pango, Python 2.5 + PyGTK a jejich knihovny z telefonu do ./sysroot
make python3                             # ARM python3 (build/out/python3-3.11.18/...)
make hildon-run SCRIPT=src/python3/hildon/proof.py SHOT=/project/build/shot.png   # Python 3, snímek po 6 s
make hildon-run SCRIPT=... PY2=1         # totéž s Pythonem 2.5 + PyGTK (tak běží mutt-hildon)
make hildon-run SCRIPT=... VNC=1         # obraz navíc přes VNC
```
- **Kam spadne snímek:** `/project` ve Workshopu je kořen tohoto repozitáře na hostiteli, takže `/project/build/shot.png` je [build/shot.png](../build/shot.png).
- **VNC:** server `x11vnc` poslouží obraz na portu 5999 kontejneru bez hesla. Adresu kontejneru ukáže `workshop -p . exec n900 -- hostname -I` (dnes `10.226.106.34`).
  Z hostitele: `remmina` nebo `vncviewer 10.226.106.34:5999` (display `:99`). Okno běží, dokud skript neskončí (proof.py po 30 s), běžící aplikace zůstane otevřená.
- **mutt-hildon na PC (vyzkoušeno):** `sysroot/opt/mutt-hildon` je vývojová kopie (soubory z `apps/mutt-hildon`), `HOME=build/fakehome` má vlastní `.muttrc` a naplněnou cache.
  Spuštění: `HOME=/project/build/fakehome PY2=1 SHOT=... scripts/hildon-run.sh /opt/mutt-hildon/mutt-hildon`. Seznam zpráv se vykreslil stejně jako na telefonu.

Omezení:
- **`hildon-desktop` na PC nejde.** Je postavený na clutteru s EGL/OpenGL ES (`libclutter-eglx`, `libGLESv2`, `libIMGegl` s ovladačem PowerVR), který pod qemu-user a Xvfb nemá co použít.
  Chybí tedy stavový řádek, přepínač oken a Maemo klávesnice; okno je celoobrazovkové. Úplnou emulaci uměl jen dřívější Maemo SDK (kompletní x86 sestavení s Mesa), to už není k dispozici.
- Rychlost je emulovaná (qemu), start Pythonu trvá pár sekund. Na rychlost se spoléhat nedá, na správnost vzhledu a logiky ano.
- Dotyk myší funguje přes VNC, kinetické posouvání (`PannableArea`) lze zkoušet jen přibližně.
- `LC_ALL=C` je nutné: glibc 2.5 ze sysrootu neumí číst jazykové soubory hostitele.
- qemu-user překládá absolutní symlinky na hostitele, proto `hildon-overlay.sh` nahrazuje symlinky v `usr/lib/pymodules` skutečnými soubory.
- Ve Workshopu je potřeba `sudo apt install xvfb x11vnc imagemagick` (nainstalováno ručně 2026-11-05, do skriptu `toolchain` zatím nepřidáno).

## hildon-desktop na PC (stav 2026-11-06)
Skutečný `hildon-desktop` (2.2.140) kreslí přes `libclutter-eglx-0.8` a OpenGL ES 2 na PowerVR (`libIMGegl`, `libpvrPVR2D_*`).
Pod `qemu-user` na PC tyto knihovny nemají čím běžet, takže ARM binárka z telefonu nejde spustit a mockováním D-Busu se to nespraví.
Cesty, které zbývají:
1. **Původní x86 rootstrap Maemo 5 SDK** (`maemo-sdk-rootstrap_5.0_i386.tgz`, Scratchbox, Xephyr): hildon-desktop tam běží nativně
   přes X11/GLX a hardware je zamockovaný. Oficiální stahování zaniklo, hledat v archivech. Je to i386, takže by šel do LXD kontejneru s i386 userlandem.
2. **Přeložit hildon-desktop ze zdrojů** (community-ssu/hildon-desktop) pro x86_64 s clutter 0.8 (backend X11 + Mesa llvmpipe), libmatchbox,
   libhildondesktop a stuby D-Busu (mce, bme, icd). Pracné, odhad dny.
3. Zůstat u dnešního `hildon-run`: okna aplikací v reálném tématu bez plochy a lišty. Pro vývoj aplikací to stačí.
