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
- **Emulated desktop (`make emulator`, `make hildon-run APP=<app>`):** `scripts/hildon-session.sh` starts the virtual screen (Xvfb 800x480), the window manager
  `matchbox-window-manager` and the top bar `scripts/hildon-shell.py` (host GTK3, 800x56; applications get 800x424 below it, like on the N900).
  The bar has stock icons of the phone (`general_applications`, `keyboard_menu`, `general_back`, `general_close` from the copied icon theme; text if the overlay is missing):
  **Apps** (application switcher like on the phone: *Running applications* with a thumbnail of each window, the current one highlighted, a close button under each;
  below it *Installed applications*, a scrollable grid with the icons of the packages; every `apps/<app>/hildon-run.sh` is an application, first lines `# Name: Mail`),
  buttons of the running windows (switching, the active one is highlighted), **Menu** (application menu of the active window) and **Back** (closes the active window like the Back button).
  Thumbnails are taken from the visible window (an obscured X window cannot be captured), every 4 s for the active one and 2.5 s after a window first comes forward.
  The desktop has the stock wallpaper of the phone (`background-1.png`, 800x480, copied into `sysroot/usr/share/hildon-emu` by `make hildon-overlay`, not part of the repository; `HILDON_BG=file.png` or `HILDON_BG=none` changes it).
  `make emulator` shows the empty desktop (VNC is on, the address is printed; `make emulator-stop` ends a session left behind, a new start does it itself) and you pick an application; `make hildon-run APP=mutt-hildon` starts the desktop with that application.
  Ctrl-C ends the session. Closing the last window leaves the emulator running.
- **Why Menu works:** `scripts/hildon-stubs/sitecustomize.py` (loaded by Python 2.5 itself when `HILDON_DEVSHELL=1`) handles F4 and Escape inside the program. `HildonAppMenu.popup()`
  shows nothing without hildon-desktop, so the items of the menu are shown in a window of our own and a tap calls the original button. Without the bar
  (`make hildon-run SCRIPT=...` with `PY2=1`) the same module draws two small Menu/Back buttons in the corner.
  `DEVSHELL_SCRIPT=22:menu,30:back` runs actions after N seconds, `DEVSHELL_DEBUG=1` logs to `/tmp/hildon-devshell.log` (inside the Workshop).
- **Applications are found automatically:** *Apps* lists (1) development copies `apps/<app>/hildon-run.sh` and (2) every package in `build/deb/*.deb` (newest of each) that has a
  `/usr/share/applications/hildon/*.desktop`: name and icon (`hicolor/48x48` and others) come from the package. A package is unpacked into `sysroot` on its first start (like an installation)
  and runs as on the phone: ARM programs through qemu-user and `binfmt_misc` (registered by `hildon-session.sh` with sudo), wrapper scripts in the host shell, `exec /opt/<app>/...` works
  because `sysroot/opt` is bind-mounted on `/opt` (qemu-user does not translate the path of `execve`; the mount is removed by `emulator-stop`). `osso-xterm -e CMD` entries open in a host xterm,
  Python 2.5 scripts (gPodder) run through the interpreter of the sysroot with the Menu/Back helper. Works: htop, CMatrix; gPodder starts and stops at the missing `com.nokia.icd` (D-Bus mocks are next).
  `make debs` first, so that the packages exist. Icons: terminal packages have none yet (TODO).
- **D-Bus mocks:** `scripts/hildon-dbus.sh` starts a private bus (`/tmp/hildon-emu-bus`, used as session and system bus by the programs) and `scripts/hildon-dbus-mocks.py` registers the
  services of the Maemo system on it: `com.nokia.icd` (connection daemon) and the MAFW media renderer (idle player). More services: one class per service in that file. The Python 2.5 module `conic`
  is replaced by `scripts/hildon-stubs/conic.py` (network is always "WLAN"). Calls are logged to `/tmp/hildon-dbus-mocks.log`. gPodder 2.20.3 starts with it.
- **yt-dlp in the emulator:** the launcher creates `~/.local/bin/yt-dlp` in the emulator home (`build/emu/home`) as a wrapper of the host yt-dlp (`build/pylibs`, `make pylibs`), because the ARM Python 3 under qemu is far too slow; QuickJS is the ARM binary of the `quickjs` package.
  Dependencies of a package that are our own packages (e.g. `curl`, `quickjs` of gPodder) are unpacked into the sysroot too.
- **Adding an application:** `apps/<app>/hildon-run.sh` (see mutt-hildon): sets `RUN_SCRIPT`, `PY2`, `HOME` and prepares demo data. Network features end with an error banner (no curl, no IMAP server).
- Not emulated: the title bar and status area, widgets, the on-screen keyboard (use the host keyboard), D-Bus services (osso is stubbed, gPodder stops at `com.nokia.icd`).

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
