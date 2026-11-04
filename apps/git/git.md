# git 2.56 s HTTPS na Maemo 5

Stav k 2026-11-04. Build a balení: [Makefile](Makefile) (`make git` v kořeni, `make -C apps/git <cil>`).
Potřebuje předem postavený [curl](../curl/curl.md) (statický `libcurl.a`, mbedTLS, zlib).
Balíčky `curl` a `git` jsou **nainstalované a ověřené na N900** (2026-11-04), viz níže.

## Proč

Na telefonu je `git 1.6.2-1` (balíček v `/usr`, 10 MB na malém kořenovém oddílu), který používá systémový
libcurl a OpenSSL 0.9.8, takže `git clone https://github.com/...` nefunguje. Nový git je slinkovaný s libcurl,
mbedTLS (TLS 1.2/1.3) a zlib staticky.

## Ověřeno na N900 (2026-11-04)

### Po instalaci balíčků (`dpkg -i`)

- `git 2.56.0-1maemo1` a `curl 8.23.0-1maemo1` jsou ve stavu `install ok installed`,
  `/usr/bin/git -> ../../opt/git/bin/git`, upgrade starého `git 1.6.2-1` proběhl.
- **`git clone https://github.com/elPytel/nokia-n900-notes.git`** do `/home/user/Git/` jako uživatel `user`:
  126 s, 61 MB repozitář (121 MB v pracovním adresáři), 47 commitů, 161 souborů, `git fsck` bez chyb,
  `git pull` přes HTTPS hlásí *Already up to date*. CA balík se vzal vestavěnou cestou
  `/opt/curl/etc/ssl/cacert.pem` (bez `-c http.sslCAInfo`).
- **19 příkazů v dočasném repozitáři** (jako `user`, `/bin/sh` je busybox ash), všechny OK: `init`, `commit`,
  `checkout -b`, `rebase`, `merge`, `stash`, `stash pop`, `cherry-pick`, `log --graph`, `diff --stat`, `tag`,
  `bisect`, `submodule status`, `gc`, `shortlog`, `archive`, `format-patch`, `am`, `request-pull`.
  Tím odpadlo hlavní riziko skriptových příkazů.

### Před instalací balíčků (zkouška přenositelnosti)

Strom `/opt/git` rozbalený do `/home/user/apps/git-test` (zkouška přenositelnosti):

- `git --version`: `git version 2.56.0`
- `git --exec-path`: `/home/user/apps/git-test/git/libexec/git-core` (**`RUNTIME_PREFIX` funguje**, git si
  najde pomocné programy podle umístění binárky)
- `git ls-remote https://github.com/octocat/Hello-World.git HEAD`
- `git clone --depth 1 https://github.com/octocat/Hello-World.git` a `git log`

CA balík jsem při zkoušce předával ručně (`-c http.sslCAInfo=…`), protože balíček `curl` ještě nebyl nainstalovaný.

## Build

Zdroje z oficiálního tarballu (kernel.org), beze změn. Rozdíly oproti běžnému buildu (viz `build.sh`):

| Nastavení | Důvod |
|---|---|
| `NO_RUST=YesPlease` | Rust je v gitu 2.5x ve výchozím stavu zapnutý |
| `CSPRNG_METHOD=urandom` | výchozí na Linuxu je `getrandom()`, který glibc 2.5 / jádro 2.6.28 nemá |
| `HAVE_SYNC_FILE_RANGE=` (prázdné) | `sync_file_range()` je v glibc až od 2.6 |
| `FSMONITOR_DAEMON_BACKEND=` (prázdné) | démon `fsmonitor` potřebuje `inotify_init1()` (glibc 2.9). Bez něj chybí jen `git fsmonitor--daemon` |
| `LDFLAGS=-Wl,--no-as-needed -lrt …` | `clock_gettime()` je v glibc 2.5 v `librt`; git na to nemá přepínač |
| `NO_EXPAT NO_PERL NO_PYTHON NO_TCLTK NO_GETTEXT NO_OPENSSL` | závislosti, které na telefonu nejsou, nebo je nechceme |
| `RUNTIME_PREFIX`, `INSTALL_SYMLINKS` | přenositelný strom; programy v `git-core` jsou symlinky na jediný `git` (jinak by `strip` rozbil hardlinky a balíček by nabobtnal) |
| `O_CLOEXEC` přes `scripts/maemo-compat.h` | chybí v hlavičkách glibc 2.5 |

Výsledek: `git` 2,9 MB, celý strom 20 MB (hodně z toho je osm samostatných programů kolem 1,7 až 2,8 MB
jako `git-remote-http`, `git-imap-send`, `git-http-fetch`, `git-daemon`), `.deb` 10,2 MB. `git` samotný chce
nejvýš `GLIBC_2.4`, `git-remote-http` kvůli libcurl `GLIBC_2.7`.

## Balíček

- Jmenuje se `git`, **nahrazuje upgradem** `git 1.6.2-1` (verze 2.56.0 je vyšší). Tím se uvolní asi 10 MB z `/usr`
  a git se přesune do `/opt/git` s odkazem `/usr/bin/git`.
- `Depends: libc6 (>= 2.5.1-1eglibc27), curl (>= 8.23.0)`. Závislost na `curl` je kvůli CA balíku
  `/opt/curl/etc/ssl/cacert.pem`, který je vestavěný v libcurl.
- Zpětně: nainstalovat `git_1.6.2-1_armel.deb` ze svých poznámek (`maemoOS_files/deb/`).
- Skripty v shellu (`git rebase`, `git stash`, `git submodule`, `git bisect`, `git am`) jedou přes `/bin/sh`
  (busybox ash). **Vyzkoušeno, fungují** (viz výše).
- Stejně jako u `curl` se v `/etc/profile.d/git-path.sh` zůstane přidání `/usr/libexec/git-core` do `PATH`,
  které po upgradu míří na neexistující složku. Je to neškodné.

## Příkazy

```bash
make curl && make git            # build (git potřebuje hotový curl)
make -C apps/git deb             # build/deb/git_2.56.0-1maemo1_armel.deb (10 MB)
make -C apps/curl install        # nejdřív curl
make -C apps/git install         # potom git (dpkg -i, upgrade 1.6.2, mění telefon)
make -C apps/git run             # git --version a ls-remote přes HTTPS
```

## Co zbývá

- Odinstalace a návrat ke `git 1.6.2` (`dpkg -r git`, instalace starého `.deb`) nezkoušena.
- `git push` přes HTTPS s tokenem, práce s SSH (`git clone git@…`, vyžaduje `ssh` klienta na telefonu).
- Delší práce: výkon na 600 MHz (klon 61 MB trval 126 s), velké repozitáře.
- Ořezat balíček: osm velkých programů (`git-daemon`, `git-http-backend`, `git-imap-send`, `git-shell`,
  `scalar`, …) většina uživatelů nepotřebuje.
- Zafixovat SHA-256 zdrojového balíčku.
