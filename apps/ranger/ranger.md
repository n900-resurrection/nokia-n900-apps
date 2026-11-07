# ranger for Maemo 5

[ranger](https://ranger.fm/) 1.9.4, a console file manager with VI key bindings. It is plain Python, so nothing is compiled for ARM:
`build.sh` copies the sources into `/opt/ranger/lib/ranger` and byte-compiles them with the ARM Python 3.11 under qemu-user (the user of the phone cannot write
into `/opt`, and without `.pyc` files the start would take many seconds on the Cortex-A8). The package depends on `python3.11`.

- **Run:** `ranger` in the terminal, or the *Ranger* entry of the application menu (starts it in `osso-xterm`). Keys: arrows or `h j k l`, `q` quits, `?` shows help.
- **Wrapper `/usr/bin/ranger`** ([ranger](ranger)): sets `PYTHONPATH`, `PYTHONUTF8=1` (glibc 2.5 has no `C.UTF-8`), `EDITOR=vim`, `PAGER=less` unless set, and starts `/opt/ranger/bin/ranger`.
  The entry script must not be called `ranger.py` (it would import itself instead of the package).
- **Measured on the N900:** first screen after about 4 s (`ranger --version` 4.7 s on the first, cold run).
- **Opening files (`rifle.conf`, [apps/ranger/rifle.conf](rifle.conf)):** it replaces the default of ranger. Images, PDF, HTML, audio and video open in the applications of the phone
  (Image Viewer, PDF Viewer, Browser, Media Player) through `hildon-open` ([hildon-open](hildon-open)), which calls the D-Bus method `mime_open` of the application (`load_url` for the browser),
  the same call that the file manager of the phone makes; spaces and `#` in the name are encoded in the URI. Text opens in `$EDITOR` (vim) or `$PAGER` (less), `r` in ranger offers the other actions
  (mplayer in the terminal, listing of zip/tar/deb archives, running scripts). A user file `~/.config/ranger/rifle.conf` takes precedence.
- **`file` stand-in** ([file](file)): the phone has no `file(1)`, which rifle and the preview script (`scope.sh`) ask for the type of files with unknown extension. `/opt/ranger/libexec/file` answers
  `file --mime-type -Lb FILE` for directories, empty files, text (also UTF-8) and the common media formats (by `od -b`, the old busybox of the phone has no `od -t`). It is at the end of the `PATH` of ranger, so a real `file` wins.
- **Limits:** previews of images, PDF and archives still need external tools (`highlight`, `pdftotext`, ...), which the phone does not have, so only directories and plain text are previewed.
  Verified on the phone: Image Viewer through `hildon-open` and all the type detection; the Media Player and PDF Viewer use the same call but were not tried yet.
- **Tests:** `make -C apps/ranger test` (on the phone: version, the text interface in a pseudo terminal).
- **Emulator:** it is listed in the *Apps* switcher of `make emulator` (an `xterm` window), see [DOC/hildon-python3.md](../../DOC/hildon-python3.md).
