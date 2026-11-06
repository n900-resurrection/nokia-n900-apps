# ranger for Maemo 5

[ranger](https://ranger.fm/) 1.9.4, a console file manager with VI key bindings. It is plain Python, so nothing is compiled for ARM:
`build.sh` copies the sources into `/opt/ranger/lib/ranger` and byte-compiles them with the ARM Python 3.11 under qemu-user (the user of the phone cannot write
into `/opt`, and without `.pyc` files the start would take many seconds on the Cortex-A8). The package depends on `python3.11`.

- **Run:** `ranger` in the terminal, or the *Ranger* entry of the application menu (starts it in `osso-xterm`). Keys: arrows or `h j k l`, `q` quits, `?` shows help.
- **Wrapper `/usr/bin/ranger`** ([ranger](ranger)): sets `PYTHONPATH`, `PYTHONUTF8=1` (glibc 2.5 has no `C.UTF-8`), `EDITOR=vim`, `PAGER=less` unless set, and starts `/opt/ranger/bin/ranger`.
  The entry script must not be called `ranger.py` (it would import itself instead of the package).
- **Measured on the N900:** first screen after about 4 s (`ranger --version` 4.7 s on the first, cold run).
- **Limits:** the phone has no `file`, so the previews that need the MIME type (scope.sh) show only directories and plain text; opening files uses the defaults of `rifle.conf` (`vim`, `mplayer`, `less`).
  A `rifle.conf` for the phone (the Media Player, the Image Viewer through `dbus-send`/`osso-document-handler`) is an open idea.
- **Tests:** `make -C apps/ranger test` (on the phone: version, the text interface in a pseudo terminal).
- **Emulator:** it is listed in the *Apps* switcher of `make emulator` (an `xterm` window), see [DOC/hildon-python3.md](../../DOC/hildon-python3.md).
