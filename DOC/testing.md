# Testy na telefonu

Testy běží **na N900** (balíček musí být nainstalovaný), spouští je počítač přes SSH. Nic se na telefon neinstaluje:
počítač pošle `tests/lib.sh` + `apps/<app>/test.sh` jednou relací do shellu (`ssh -q n900 sh -s`).

## Spuštění
```sh
make test                    # všechny aplikace s apps/*/test.sh, na konci souhrn
make -C apps/curl test       # jedna aplikace
make -C apps/busybox test TEST_SHELL=bash5     # jiný shell pro test (výchozí sh = busybox ash)
```
Chyba nějakého testu vrací nenulový kód (`make` skončí chybou), takže jde použít v skriptech.

## Jak psát test (`apps/<app>/test.sh`)
Soubor je prostý POSIX shell, nezahrnuje `lib.sh` (ten se připojí před něj) a končí `summary`.
```sh
TEST_NAME=jq
need_pkg jq                                   # balíček je nainstalovaný (dpkg -s)
contains version "jq-1.8" jq --version        # výstup obsahuje text
t filter-map '[2,4]' sh -c 'echo "{\"a\":[1,2]}" | jq -c ".a|map(.*2)"'   # výstup se přesně rovná
ok  config-installed test -r /etc/ntp-sync.conf                            # příkaz skončí kódem 0
tmpdir                                        # čistý pracovní adresář (v /home/user, /tmp má jen 1 MB)
skip bash5-interplay "bash5 is not installed" # přeskočeno s důvodem
summary
```
Pomocné funkce a jejich popis jsou v [tests/lib.sh](../tests/lib.sh).

## Zásady
- Test musí být **bezpečný**: žádné přihlášení do účtů, žádné odesílání pošty, žádné měnění času nebo systémových souborů.
  Přihlášení k serverům se ověřuje jen pozdravem serveru (IMAP `* OK`, SMTP `220`) bez hesla.
- Test musí běžet **opakovaně** a po sobě uklidit (`tmpdir` + `summary`).
- Síťové testy potřebují Wi-Fi a správný čas (`ntp-sync`), jinak selže ověření certifikátu.
- Nejdřív `need_pkg`, ať je hned vidět, že chybí instalace, a ne desítky dalších chyb.

## Screenshots of the phone

The built-in screenshot of Fremantle (the shortcut the user presses on the phone) saves PNG files, 800x480, into
`/home/user/MyDocs/.images/Screenshots/Screenshot-YYYYMMDD-HHMMSS.png` (on the PC: `scp n900:/home/user/MyDocs/.images/Screenshots/<file> .`).
They show what the user sees (menu, Application Manager, running tasks), which logs do not. They are personal: keep them out of the repository
(scratchpad only), and use anonymized data when a screenshot is meant for the docs.

## Stav (2026-11-05)
| Aplikace | Testů | Výsledek |
|---|---|---|
| bash5 | 17 | prošly |
| busybox37 | 21 | prošly |
| curl | 9 | prošly |
| git | 6 | prošly |
| jq | 9 | prošly |
| ntp-sync | 6 | prošly |
| wget | 7 | prošly |
| htop3 | 6 | prošly |
| cmatrix | 5 | prošly |
| cbonsai | 5 | prošly |
| tty-clock | 5 | prošly |
| wordgrinder | 4 | prošly |
| mutt | 15 | prošly |
| sfeed | 11 | prošly |
| mutt-hildon | 8 | prošly |
| camel-lite-ssl3 | 9 | prošly |
| python3 | 30 | prošly |
| apt-transport-curl | 12 | prošly |
| msmtp | 7 | prošly |

Aplikace s terminálovým rozhraním (htop3, cmatrix, cbonsai, tty-clock, wordgrinder) mají jen kouřové testy: balíček, odkaz, ikona, `--help`/`--version`, chybějící knihovny. Vzhled a ovládání v terminálu se testovat nedá. Při psaní jsme narazili na: `/tmp` je tmpfs 1 MB (clone gitu selhal),
`readlink /proc/$$/exe` v `bash -c` s jediným příkazem hlásí sám sebe (bash příkaz spustí přes `exec`), `jq` vrací 5 při chybném JSONu.

## Testing without the phone: emulation (2026-11-09)
Everything runs INSIDE the Workshop with `qemu-user` (and the package `qemu-user-static`, which the chroot needs; it is in the `toolchain` action of `.workshop/n900.yaml`).
Four levels, from the cheapest:

| Level | Command | What it is |
|---|---|---|
| phone-like limits | `scripts/qemu-n900 PROGRAM...` | qemu-arm with `QEMU_UNAME=2.6.28` (the kernel version the program sees), one CPU (`taskset -c 0`), a private **1 MB `/tmp`** (tmpfs in a user namespace: "No space left on device" like the phone), glibc 2.5 of the sysroot. Switches: `--no-uname`, `--no-cpu`, `--no-tmp`, `--no-limits`. Not emulated: RAM (qemu-user cannot cap the resident memory of the guest) and the speed of the CPU |
| smoke tests | `make qemu-smoke [APP="jq age"]` | `scripts/qemu-smoke.sh`: version and one real function of each built program (jq, ripgrep, fd, fzf, age with an encrypt/decrypt round trip, ncdu, htop, links, ...). No packaging, no phone, no network |
| per-app tests | `make qemu-test [APP=tmux]` | `apps/<app>/qemu-test.sh` (tmux: sessions, UTF-8 through `send-keys`/`capture-pane`, panes; openssh: sshd/ssh/sftp over loopback) |
| the test suites of the phone | `make emu-test [APP="jq tmux"]` | `scripts/emu-test.sh`: the real `tests/lib.sh` + `apps/<app>/test.sh` in a **chroot of an emulated phone** (`build/emu-root`, 370 MB, not in git: the SDK sysroot, busybox 1.37 with its applets, `/etc/passwd`, a `dpkg` and a `ldd` stand-in). The `.deb` of the app and of our packages it depends on are unpacked into it; the shell reads the script from stdin (`sh -s`) as on the phone. The chroot has the same limits (kernel 2.6.28, one CPU, 1 MB `/tmp`) and the network of the Workshop. `RESET=1` builds the root again; `scripts/emu-test.sh --scripts` also runs the `postinst` |

Result of the first full run of `make emu-test` (all 50 suites, 1 min 50 s): 26 suites pass completely (age, amfora, bat, cbonsai, cmatrix, dialog, fd, file, fzf, gurk, jq, links, micro, nano, ncdu,
ranger 21 checks, ripgrep, rsync, screen, signal-bridge, tig, tmux, tty-clock, whiptail, wireguard-go, wordgrinder); with the network added (the resolver configuration of the host is copied into the root)
also curl (TLS 1.3 to GitHub), git (clone over HTTPS), wget, sfeed, msmtp and ntp-sync. The rest fails for reasons of the emulation, not of the packages:
- tests that assume the **stock packages of the phone** (`system-htop-untouched`, `system-bash-untouched`, `system-busybox-untouched`, `system-python-untouched`, `system-vim-untouched`),
- **maintainer scripts that are not run** by default (diversions: apt-transport-curl, microb-nss, camel-lite; `haze.manager`: libsignal-purple, purple-echo; `.bashrc`: terminfo-256color; host keys: openssh),
- **ptrace** does not work through qemu-user (strace),
- things that need the real system: the phone address book, `cmcli` (ca-certs-n900), the apt database of the phone (apt-n900), Python 2.5 (mutt-hildon).
Known limit of qemu-user: a local `rsync` copy fails in the receiver (`change_dir ... No such file or directory`), although the same copy passes on the phone.
`make test` on the phone stays the reference; the emulation finds a program that does not start, a missing library or a broken feature before the package goes to the phone.
`scripts/locale-overlay.sh` (`make locale-overlay`) copies the locale archive of the phone into the sysroot (UTF-8 locales for tmux and others). `scripts/qemu-binfmt.sh` makes sure that the kernel uses the static qemu-arm (flag F).
