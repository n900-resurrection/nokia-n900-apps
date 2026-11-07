# Signal in the native Maemo messaging UI (plan, 2026-11-07)

Goal: Signal appears as an ordinary account in the Accounts settings and its conversations in the stock Conversations and
Contacts applications, next to Jabber, so that the phone has one messaging GUI. Status: **plan only, nothing of it built yet.**
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
0. **Feasibility with a dummy protocol (the biggest unknown).** A "loopback" libpurple plugin (answers every message with an echo)
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
