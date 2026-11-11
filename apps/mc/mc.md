# Midnight Commander 4.8.33 for Maemo 5

Two-panel file manager in the terminal (`mc`), with the editor `mcedit` and the viewer `mcview`. Second application on the static [GLib 2.66](../glib2/glib2.md); ncursesw (UTF-8) is linked statically as well.

```sh
make -C apps/mc install     # build (when out of date), deb, scp, dpkg -i
make -C apps/mc test        # 8 tests on the phone
mc                          # in a terminal (xterm); mcedit file; mcview file
```

- Installs to `/opt/mc` (skins, syntax files, help, extfs scripts), links `/usr/bin/{mc,mcedit,mcview,mcdiff}`. They point to a small wrapper `/opt/mc/bin/mc` that starts `mc.bin` (`-e`, `-v`, `-d` by the name it was called by).
- **Redraw after the start:** `osso-xterm` changes its size after the program starts, and the first screen of mc came out garbled (panels shifted, stray text) until a key was pressed. The wrapper sends mc a `SIGWINCH` after 1 and 2 seconds, so it reads the final size and redraws; the screen settles by itself after a moment (verified in `osso-xterm`, 2026-11-11). `mc -u` (no subshell) did not help, so the subshell is not the cause.
- Built without X11, GPM, SFTP (libssh2), aspell and NLS. The archive handlers (`extfs.d`) are shell scripts and need the tools they call (tar, unzip ...).
- The N900 keyboard has no F-keys: use `Esc` followed by a digit (`Esc 1` = F1 help, `Esc 3` view, `Esc 4` edit, `Esc 5` copy, `Esc 0` = F10 quit), or the on-screen function keys of the terminal, or a Bluetooth keyboard ([DOC/bluetooth-keyboard.md](../../DOC/bluetooth-keyboard.md)).
- [build.sh](build.sh): libtool records `-lncursesw` and `-lglib-2.0` in `libmc.la`, and gold resolves them to the system `.so` files of the sysroot (GLib 2.20, `libncursesw.so.5`, missing on the phone). The script drops them from the `.la` files, gives the full paths of the static libraries in `LIBS` and links `mc` once more after `make install` (the install step relinks with the old flags). The result has only libc, libpthread, librt and libutil as dependencies.

## Verified (2026-11-11)

- On the phone: 8 tests; `mc` started in `screen` as `user` with `TERM=xterm`: both panels, the directory list, frames and the bottom bar were drawn, `Esc 0` quit.
- In the real `osso-xterm` (screenshot): panels, Czech UTF-8 text, frames and the F-key bar are right once the redraw has happened.
- Not checked: the editor (`mcedit`) in the terminal, the viewer only in `screen`, other skins (the default 8-colour one is bright blue and cyan), copying larger files, archives, memory use and the speed on the CPU of the phone.
