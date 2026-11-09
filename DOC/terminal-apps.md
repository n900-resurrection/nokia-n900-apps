# Terminal applications worth packaging for the N900 (research, 2026-11-07)

Based on what the phone has now (checked over SSH), the build routes we already have (C + ncurses like cmatrix/htop, OpenSSL 3 and other
libraries in `build/deps`, static Rust/Go binaries) and general knowledge of the projects. Package versions and exact sizes were not
checked one by one: the estimates are marked as such. **Not built or tested yet** unless a line says so.

## Constraints that decide the list
- **256 MB RAM**, about 10 MB free in normal use (swap 768 MB helps), ARMv7 Cortex-A8 600 MHz, 800x480 terminal (about 80x24 with the keyboard open),
  kernel **2.6.28** (no `epoll_pwait` etc.; Rust/tokio and Go work, see `apps/rust`, `apps/go`), root file system 57 MB free (`/opt` is on it: keep
  packages small or install into `/home/opt`), `/home` has about 850 MB free.
- Libraries on the phone: **glib 2.20** (too old for irssi, WeeChat, current mc, profanity: they need glib 2.3x-2.5x), ncurses 5.7, libpcap 1.1.1, OpenSSL 0.9.8
  (TLS 1.0: useless for the internet), zlib 1.2.3, libasound 1.0.20 with plugins, slang 2.0.6. `/dev/net/tun` exists. No libevent, no libmagic (`file` is missing,
  `apps/ranger/file` is only a stand-in).
- Missing tools (checked): tmux, screen, mc, lynx/links/w3m, irssi/weechat, cmus/mpg123, ncdu, tig, rsync, strace, gdb, lftp, mtr, tcpdump, ssh server newer than OpenSSH 5.1
  (2008). Present: busybox applets (see `busybox37` too), mplayer, git, nmap, lsof, python3, perl, sqlite3, curl, wget, nc, gpg 1.4.
- Packaging rule of the project: own prefix in `/opt/<app>`, static or with its own libraries, links in `/usr/bin`, never replace a system package (see htop3, vim9).

## Recommended, in order (value for this phone / effort)

### Tier 1: small C programs, the recipe is known (ncurses 5.7 of the sysroot, libraries built into `build/deps`)
| Application | Why | Notes |
|---|---|---|
| **tmux** 3.x | several shells on a small screen, survives a dropped SSH session | needs libevent (build it, small); the stock terminal has no tabs |
| **ncdu** 1.x (C) | what fills the 2 GB `/home` and the 57 MB root | tiny; ncdu 2.x is Zig: use 1.x |
| **strace** | the phone has none; we needed it for the Application Manager and Feeds investigations | kernel 2.6.28 has ptrace; old kernel headers in the sysroot may need a patch |
| **rsync** 3.x | backups and syncing from the PC over SSH (only scp/tar exist) | needs zlib (own build); a client and a server over SSH |
| **file** 5.x + libmagic | replaces the shim of ranger/rifle with the real thing | small; compile the magic database (`magic.mgc`) |
| **lynx** or **links** (text mode) | a browser with TLS 1.3 (OpenSSL 3 is built), the stock MicroB is stuck on TLS 1.0 | links2 needs less (no gettext); lynx has gopher; both work as `$BROWSER` for mutt |
| **OpenSSH 9.x** (client, server, sftp) | the phone has OpenSSH 5.1 (2008) with root password login: a modern sshd with key-only login is a real security gain (see the TODO item on security) | needs zlib and OpenSSL 3 (own); install the server only on request, never replace `/usr/sbin/sshd` silently |
| **tig** | a TUI for the git of the phone | plain ncurses |
| **screen** 5.x | the alternative to tmux; the Maemo extras version is old | tmux first |

### Tier 2: Rust/Go static binaries (the toolchains exist, ARMv7 musl static, a few MB each)
| Application | Why | Notes |
|---|---|---|
| **ripgrep**, **fd**, **bat** | fast search and viewing | ripgrep is a few MB; `bat` needs more RAM to start (syntect) |
| **fzf** (Go) | fuzzy finder for shell history and files | small |
| **micro** (Go) | an editor with normal keys (Ctrl-S, Ctrl-Q, mouse) for people who do not like vim | about 12 MB RAM at start; check the keyboard of the N900 |
| **wireguard-go** + `wg` (Go) | a VPN for the phone on mobile data (kernel has no WireGuard, user space needs `/dev/net/tun`) | needs a server; fits the security topic |
| **age** (Go) | file encryption without gpg configuration | tiny |
| **amfora** (Go) | a browser for Gemini space: tiny pages, TLS 1.3 | optional |
| **bk** (Rust) or similar | reading epub books on the terminal | optional; check RAM |

### Tier 3: useful but harder (dependencies, RAM)
| Application | Problem | Idea |
|---|---|---|
| **irssi**, **WeeChat** | need glib newer than 2.20 | build a private glib (or Rust: `senpai`/`halloy` are not terminal): lower priority |
| **profanity**, **mcabber** (XMPP) | glib and libstrophe; but they would use OpenSSL 3 and so fix the TLS problem of Pidgin (`DOC/messengers.md`) | after the XMPP test with Pidgin shows whether NSS is the problem |
| **Midnight Commander** 4.8 | glib 2.26+ | ranger already works very well |
| **calcurse** | ncurses; calendar and todo, no server | the roadmap dropped calendar sync: a local calendar would be enough; check 4.x/5.x needs |
| **cmus** | needs an ALSA/PulseAudio output (the phone plays through PulseAudio and the Media Player) | the Nokia player and gPodder cover it; try only if wanted |
| **gdb** | big; useful for the Application Manager hang | `strace` first |
| **mtr**, **tcpdump**, **iftop** | libpcap 1.1.1 is on the phone; small | network diagnosis on the go |
| **nethack**, **frotz** (interactive fiction), **bsd-games** | fun, small | low priority |
| **pass** | shell + gpg 1.4 (present) | a script package |

### Not worth it
- **Impala** (Wi-Fi TUI): needs `iwd`, the phone has `icd2` (see TODO).
- **Heavy TUIs**: lazygit, bottom/btm (RAM), helix, taskwarrior, notmuch + a full mail stack (mutt, msmtp and mutt-hildon exist), newsboat (sfeed exists),
  ncmpcpp/mpd, ffmpeg-based players.

## Status (2026-11-07)
Built, packaged, tested in the emulator (qemu-user) and on the phone: **tmux 3.8** (libevent built without `eventfd`: the glibc 2.5 of the phone has no such wrapper),
**ncdu 1.22**, **strace 6.19** (the bundled kernel headers must come before the 2.6.28 ones of the sysroot, see `apps/strace/build.sh`), **file 5.48** (needs a native
`file` of the same version to compile the magic database). tmux refuses to start when the system has no UTF-8 locale at all (it tries `en_US.UTF-8` and `C.UTF-8` itself); the phone has them in its locale archive. The SDK sysroot has
only empty placeholder files, so under qemu-user tmux used to be testable on the phone only. `make locale-overlay` (once) copies the locale archive of the phone into `./sysroot`, then
`make -C apps/tmux qemu-test` (6 checks: sessions, UTF-8 text through `send-keys`/`capture-pane`, panes) runs under qemu-user without the phone (2026-11-09). **rsync 3.5.2** is built and tested too (8 tests on the phone). All five are in the apt repository.

**links 2.30** (text browser, HTTPS through the static OpenSSL 3, so TLS 1.3 works; Mozilla CA bundle in `/opt/links/etc/cacert.pem` and the `/usr/bin/links`
wrapper sets `SSL_CERT_FILE`) is built, packaged, tested on the phone (8 tests, including `links -dump https://example.org`) and in the repository.

**ripgrep 15.2.0**, **fd 10.5.2** (Rust, `scripts/cargo-install.sh`, static musl, built from crates.io), **fzf 0.75.0**, **micro 2.0.15**, **age 1.2.1** (Go,
`scripts/go-install.sh` or a clone + build for micro, static, with the patched Go 1.24 of `apps/go`; age 1.3 needs Go 1.25) and **wireguard-go 0.0.20250522** with `wg` (C, from
wireguard-tools; `NLM_F_DUMP_INTR` is defined by hand, the 2.6.28 headers lack it) are built, tested on the phone and in the repository. WireGuard runs in user space
over `/dev/net/tun` (exists on the phone) and `wg-n900 up|down <conf>` replaces `wg-quick` (the phone has only the busybox `ip`). Verified: keys, versions, the helper
usage. **Not verified**: bringing a tunnel up (needs a server and changes the routing of the phone; ask first).

**bat 0.26.1** (Rust; the syntax engine oniguruma is C, so `MUSL=1` makes `scripts/cargo-install.sh` use the musl cross gcc; the wrapper `/usr/bin/bat` sets `BAT_PAGER=cat`
because the busybox `less` of the phone rejects `-R`) and **tig 2.6.1** (needs ncursesw: linked statically, the phone has only libncurses5; uses the git package) are built, tested
on the phone and in the repository.

**amfora 1.11.0** (Gemini browser, Go, cloned and built because its `go.mod` has replace directives; checked on the phone with a real page in a pty), **screen 5.0.2**
(classic multiplexer, system `screenrc` with a status line, sockets in `~/.screen`) are built, tested and in the repository. **batcat** is only the Debian/Ubuntu name of
bat (there `bat` is another program): the bat package installs the alias `/usr/bin/batcat` too.

**dialog 1.3-20260721** (static ncursesw) and **whiptail 0.52.25** (newt; slang 2.3.3 and popt linked statically, the phone has a slang without headers) are built, tested on
the phone (menu and checklist drawn in a pty) and in the repository. The upstream site of dialog refuses the default curl User-Agent, so both builds take the upstream
tarballs from the Debian archive. **apt-n900** (`apps/apt-n900`, own repository and submodule) adds a friendly `apt` command over apt-get.

**terminfo-256color 1.0** (`apps/terminfo-256color`) fixes `Color number is greater than COLORS-1 (7)` in ranger, cbonsai and similar programs: the phone has only 8-colour
terminfo entries and the stock terminal sets `TERM=xterm`. The package adds `xterm-256color`, `screen-256color` and `tmux-256color` to `/usr/share/terminfo` (compiled by
`build.sh` in the legacy format that ncurses 5.7 reads; the `pairs#65536` of ncurses 6 is lowered to 32767). No system file is replaced. Its `postinst` also appends a marked
block (`# BEGIN/END terminfo-256color`) to `/home/user/.bashrc` that switches `TERM=xterm` to `xterm-256color`; `postrm` removes the block. Tested on the phone (8 tests).
**Revision 1maemo2 (2026-11-09):** the first revision compiled `xterm-256color` from the modern ncurses entry, which draws line characters with `ESC ( 0`. The terminal of Maemo does not
understand that: the frames of `dialog` (and so of `apt tui`) were broken. The stock `xterm` entry of the phone uses `SO`/`SI` (`smacs=^N`, `rmacs=^O`, `enacs=\E(B\E)0`), so
`xterm-256color` is now generated from it (`apps/terminfo-256color/xterm-256color.src`: the phone entry with 256 colours and the 256-colour `setaf`/`setab`); `screen-256color` and `tmux-256color`
still come from ncurses 6 (the multiplexer draws the frames itself). A test (`acs-shift-out`) guards it. Verified with the bytes dialog sends: identical to `TERM=xterm`.

**ca-certs-n900 1.0** (`apps/ca-certs-n900`) adds the current Mozilla root certificates (the list of the curl build, 118 certificates) to the private certificate domain `ssl-ca`
of the user (`~/.maemosec-certs/ssl-ca`, Maemo certificate manager `cmcli`); the phone has only roots from 2010 in the read-only system domain `common-ca`, which is not touched.
`ca-certs-n900 install|remove|status [user]`; the package runs install in `postinst` and remove (exactly its own certificates, ids in `/opt/ca-certs-n900/ids`) in `prerm`.
Verified: the mechanism with a temporary test CA and an `openssl s_server -tls1` on the PC (`cmcli -v` fails without the CA and gives "Verified OK" with it; **MicroB opened
the page without a warning**, the first load was slow). Also verified on a real public site: `https://tls-v1-0.badssl.com:1010/` (TLS 1.0, Let's Encrypt chain) loads in MicroB without a warning. MicroB (Gecko 1.9.2, NSS 3.12.6) speaks only TLS 1.0, so sites that disabled it still fail.

**OpenSSH 10.6p2** (`apps/openssh`, client and server in `/opt/openssh`, the system 5.1 is untouched; `ssh-modern`, `scp-modern`, `sftp-modern`, `ssh-keygen-modern`
in `/usr/bin`) is built and packaged, and tested **only under qemu-user** (`make -C apps/openssh qemu-test`: ssh key login with the shipped ARM client and with the host
client, a refused wrong key, sftp transfer), **never on the phone** by agreement. Things to know when it is first installed:
- the sandbox of sshd is `rlimit` (the 2.6.28 kernel has no seccomp filter, only the strict mode); the configure test for it cannot run when cross compiling,
  so `apps/openssh/build.sh` forces the answer (select/poll work with the descriptor limit on Linux). Not verified on the real kernel;
- the qemu test uses a scratch build of sshd where `closefrom()` and the `setrlimit()` calls of the sandbox are no-ops, because under qemu-user they hit the emulator
  itself (its descriptors and file size limit). The shipped sshd is unchanged;
- the package starts nothing. `postinst` creates host keys (ed25519, RSA 3072) and the `sshd` user if missing. The default config listens on port **2222**, keys only,
  no root, `AllowUsers user`: put a public key into `/home/user/.ssh/authorized_keys` first;
- old servers (OpenSSH 5.1 of the phone) need `-o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedAlgorithms=+ssh-rsa` and possibly `KexAlgorithms=+diffie-hellman-group14-sha1`
  with the new client.

## Suggested order of work
1. **tmux + ncdu + strace** (a new `apps/<name>` each, the recipe of cmatrix/htop; strace helps the Application Manager investigation).
2. **file/libmagic** (finishes rifle) and **rsync**.
3. ~~links with OpenSSL 3, OpenSSH 10~~ done (OpenSSH only in qemu; the hardening TODO decides when the new sshd goes on the phone).
4. **ripgrep + fd + fzf**, **micro**, **wireguard-go**.
