# Signal in the native Maemo messaging UI (plan, 2026-11-07)

Goal: Signal appears as an ordinary account in the Accounts settings and its conversations in the stock Conversations and
Contacts applications, next to Jabber, so that the phone has one messaging GUI. Status: **step 0 passed on the phone (2026-11-07); the rest is not built yet.**
What is marked *(checked)* was looked at on the phone, the rest is an estimate.

## How a new protocol gets into the stock UI (checked on the phone)
The stock UI talks to Telepathy; `telepathy-haze` 0.3.2 turns libpurple protocol plugins into Telepathy protocols. Three
pieces are needed, all files:
1. **A libpurple 2.7 protocol plugin** (`.so` in `/usr/lib/purple-2/`, as `libicq.so`, `libjabber.so` are).
2. **A protocol entry in `/usr/share/telepathy/managers/haze.manager`** (a `[Protocol signal]` section with the parameters) so that
   Mission Control knows the protocol.
3. **An account profile** `/usr/share/osso-rtcom/signal.profile` (like `icq.profile`: `Manager=haze`, `Protocol=signal`,
   `ConfigurationUI = haze-plugin`, the presences) plus an icon `im-signal.png` in `/usr/share/icons/hicolor/48x48/hildon/`. The
   package `account-plugin-haze` ships these for AIM, ICQ, Yahoo and others.

## Architecture
```
Conversations / Contacts  <->  Mission Control  <->  telepathy-haze  <->  libsignal-purple.so (C, small)
                                                                              | unix socket, one line per message
                                                                       signal-bridge (Rust, static musl)
                                                                              | presage + libsignal (as in gurk)
                                                                         Signal servers (TLS 1.3, rustls)
```
- **signal-bridge**: a daemon built on presage, the library gurk uses (gurk 0.10.2 already builds and runs on the phone). It owns the
  Signal data store, receives messages, sends messages, lists contacts and groups, handles attachments. It speaks a simple
  line protocol (tab separated, escaped) on `/var/run/signal-bridge.sock`, so the C side needs no JSON library.
- **libsignal-purple.so**: the thin plugin: `login` connects to the socket, `send_im` writes a line, incoming lines become
  `serv_got_im`, contacts become buddies. Written against libpurple 2.7.7 (headers from the pidgin 2.7.x source: not in the sysroot yet).
- **Linking the device** (the QR code) stays outside the account dialog: `signal-bridge link` shows it in a terminal or a Hildon
  window; the account only needs the phone number.
- The data store of gurk in `/root/.local/share/gurk` is a separate device link; the bridge makes its own.

## Steps
0. **Feasibility with a dummy protocol (the biggest unknown). Prepared: package `purple-echo` (`apps/purple-echo`), built, NOT installed.** A "loopback" libpurple plugin (answers every message with an echo)
   plus the manager entry and the profile: does Mission Control offer the account, does Conversations show the chat? Needs the
   pidgin 2.7.x headers and changes the phone (a plugin in `/usr/lib/purple-2`, an edit of `haze.manager`, a restart of Mission
   Control). Do it only after the user agrees; keep a backup of `haze.manager`.
1. signal-bridge: receive and send text messages, contacts (reuse the gurk build recipe, `apps/gurk`).
2. libsignal-purple: connection, buddies, messages, delivery state.
3. Groups, attachments (images), read receipts, typing indicator, avatars.
4. Packaging (`libsignal-purple`, `signal-bridge`, profile, icon), a start script (the bridge runs as a service, not from the plugin),
   repository.

## Open questions
- Does `haze` 0.3.2 pass the contacts of a third-party protocol to the stock Contacts (libosso-abook)? Estimate: yes, as for ICQ.
- Memory: the bridge is the gurk core without the TUI (gurk measured about 7 MB RSS), the plugin lives inside the haze process.
- Notifications and the "Conversations" statusbar applet work through Telepathy, so they should come for free.
- WhatsApp or Messenger later can reuse the same pattern (`purple-gowhatsapp`, `purple-facebook` are libpurple plugins already).

## Step 0: what is prepared (2026-11-07)
`make debs APP=purple-echo` builds `purple-echo_0.1-1maemo1_armel.deb` (13 kB): `libecho.so` (the plugin, about 100 lines of C, built against the headers of
pidgin 2.7.7; every libpurple symbol it needs was checked against `libpurple.so.0.7.7` taken from the phone), the symlink in `/usr/lib/purple-2`, the
`[Protocol echo]` block that `postinst` appends to `haze.manager` (backup: `haze.manager.orig-echo`; `postrm` removes the block), `echo.profile` and an icon.
Not tested on the phone. Plan for the test, each point needs the user's agreement:
1. `make debs APP=purple-echo INSTALL=1` (installs, restarts nothing), `make -C apps/purple-echo test` (checks the files).
2. Restart Mission Control: reboot is the safe way.
3. Settings > Accounts > add account "Echo (test)", any name; open Conversations, write to `echo-bot`: the answer is `Echo: <text>`.
4. If it fails: `dpkg -r purple-echo` restores `haze.manager`; look into `~/.purple` or run `telepathy-haze` with `PURPLE_DEBUG`.

## Result of step 0 (2026-11-07)
`purple-echo` installed on the phone, Mission Control restarted by a reboot: the account "Echo (test)" is offered in Settings > Accounts, connects, and the
Conversations application shows the chat with `echo-bot` and the answers `Echo: <text>`. So a third-party libpurple protocol plugin works in the stock
messaging UI with just: the plugin `.so`, a block in `haze.manager`, an account profile and an icon. The architecture above stands; next is step 1 (signal-bridge).

## Step 1: signal-bridge (2026-11-07)
`apps/signal-bridge` (Rust, presage rev `94b3978` as in gurk, static musl, built into the target directory of gurk, 15 MB): subcommands `daemon`, `contacts`, `groups`,
`whoami`. It opens the encrypted presage store of gurk (`~/.local/share/gurk/signal.sqlite`, passphrase read from `~/.config/gurk/gurk.toml`), so no second device link
is needed; **gurk and the bridge must not run at the same time** (the server allows one connection per device). The line protocol is described in the header of
`src/main.rs`. With `--allow UUID,...` only listed recipients can be written to (a guard for the tests).
Checked on the phone (no network, nothing sent): the store opens, `whoami` prints the own identity, `contacts` and `groups` list the store (one contact, no group at the time).
Opening the store takes about 13 s per connection on the phone (sqlcipher key derivation); the daemon pays it once at start.
A backup of the store was made first (`signal.sqlite.bak-20261107`, mode 600).

Receiving was checked too (2026-11-07): the daemon received the replies written on the main phone to "Note to Self" and presage stored them. A message that arrives while
no client is connected is not lost: the client asks for it with `HISTORY` (or `signal-bridge messages THREAD [--since MS]` prints it). A message sent by the bridge
itself shows up in the store as `MSG` with our own UUID as the sender (the plugin must treat sender == own UUID as an outgoing message); a message written on the main
phone arrives as `SENT`. Next: step 2, the libpurple plugin `libsignal-purple` (connect to the socket, buddies from `CONTACT`, `MSG` to `serv_got_im`, `send_im` to `SEND`,
history after login), a start script/service for the daemon, packaging.

## Step 2: libsignal-purple (2026-11-07, built, not tested in the UI yet)
`apps/libsignal-purple` (`signal.c`, about 400 lines of C, libpurple 2.7.7 headers; all 28 libpurple functions it uses exist in the libpurple of the phone):
protocol `signal`, no password, the account name is free. On login it connects to the socket of signal-bridge; when there is none it starts
`/opt/signal-bridge/bin/signal-bridge-start` and retries for two minutes (the daemon needs about 45 s to open the encrypted store and connect). `READY` makes the
account connected, `CONTACT` lines become buddies (the buddy name is the Signal UUID, the alias is the contact name; the own contact is shown as "(Note to Self)"),
`MSG` becomes an incoming message, `SENT` (written on another device) is shown as a sent message, `send_im` sends `SEND`. After login the plugin asks `HISTORY` for each contact
since the newest message it showed (kept in the account setting `last-message-ts`), so messages that arrived while the phone was offline are not lost; on the very first login
only messages from now on are shown. Not yet: groups, attachments, typing, receipts, avatars, new contacts by number.
Packages: `signal-bridge` (6.5 MB, daemon, `signal-bridge-start`, `sb-client`; installed and tested on the phone, 6 tests) and `libsignal-purple` (18 kB; plugin, the
`[Protocol signal]` block in `haze.manager` with a backup `haze.manager.orig-signal`, profile, icon; depends on `signal-bridge`). `signal-bridge` refuses to start twice (checks the socket).
Test in the UI (changes the phone: `haze.manager`, Mission Control restart): `make debs APP=libsignal-purple INSTALL=1`, reboot, Settings > Accounts > Signal, any name;
write to "(Note to Self)" in Conversations. Gurk must not run at the same time. Remove `purple-echo` afterwards (`dpkg -r purple-echo`).
