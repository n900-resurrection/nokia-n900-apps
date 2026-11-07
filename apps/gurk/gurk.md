# gurk-rs (Signal) on the N900

Verified 2026-11-07: **gurk 0.10.2** (commit 49f4295, presage/libsignal, sqlx + bundled sqlcipher) cross-builds for the N900 and `gurk --version` runs on
the phone. A static musl binary, 23 MB stripped (copy it to `/home/user/apps`, not to `/tmp` or `MyDocs`). The build takes about 4 minutes
(`make -C apps/rust build` first for the toolchain, then `make -C apps/gurk build`, `make -C apps/gurk push DEVICE=n900`).

## How
- Same target as [../rust/rust.md](../rust/rust.md) (armv7 musl, static). The C parts of the crates (sqlcipher, openssl) are compiled with the musl cross gcc
  from musl.cc (`build/rust/musl-cross`, downloaded by `build.sh`; its checksum is printed but not pinned yet), so they see the musl headers.
- Build tools in the Workshop: protobuf-compiler, cmake, clang, libclang-dev, perl (installed by `build.sh` with sudo).

## Verified on the phone (2026-11-07)
- The device was linked to a personal Signal account with the QR code; a message sent from the main phone arrived in gurk after a while
  and the user's own channel (Note to Self) appeared. The first run needed full CPU for about a minute (keys, sqlcipher, first sync), then the
  process is idle (about 7 MB RSS, 7 threads). Data: `~/.config/gurk/gurk.toml`, `~/.local/share/gurk/{signal,gurk}.sqlite` (they were created
  under root because gurk was started as root; the files of the database are world-readable, `chmod 600` them).

## Not done yet
- **RAM:** the phone has about 10 MB free of 256 MB (swap helps); how much gurk needs with a database and a connection is to be measured.
- Sending messages and attachments, long-running behaviour (battery, display off, Wi-Fi loss).
- Package `gurk_0.10.2-1maemo1_armel.deb` (9.7 MB; menu entry "Signal (gurk)" that starts it in the terminal, icon with `make icon`, `make -C apps/gurk test`):
  built and installed, not added to the apt repository yet (size). Started from the menu it runs as `user`, so it needs a new link (a second linked device);
  the one created as root (`/root/.config/gurk`) can be removed in Signal on the main phone.
