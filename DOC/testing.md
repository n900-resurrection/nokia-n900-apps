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
