# TODO

Stav k 2026-11-04. Odškrtnuté = hotovo a ověřeno, neodškrtnuté = zbývá.

## Rozpracované

- [ ] **Jak se balíček chová v Application Manageru** (`Section: user/office`, `XB-Maemo-Display-Name`).
  - Ověřeno: instalace přes `dpkg -i`, `dpkg -L`, `ldd`, spuštění z menu (ikona).
  - Zbývá: instalace z Application Manageru (ne přes `dpkg`), zobrazení v kategorii *Office*, zobrazované jméno
    a popis, chování při aktualizaci a odinstalaci, varování o nepodepsaném zdroji. `.desktop` nemá `Icon=`,
    takže menu ukazuje výchozí ikonu. Vlastní ikonu přidat (`XB-Maemo-Icon-26` v `control` + `Icon=` v `.desktop`).
- [ ] **Příprava Proxmox kontejneru** (server Zalman): LXC s nginx (HTTP, jen LAN) + reprepro nebo aptly
  pro repozitář `n900dev`, později kopie `maemo.plan9.de`. Návrh viz [DOC/packaging.md](DOC/packaging.md),
  sekce 5, a [DOC/mirror.md](DOC/mirror.md).

## Z rozboru (k potvrzení)

- [ ] Pozdější import `.deb` do repa (`reprepro includedeb`) a přidání katalogu `n900dev` v telefonu přes HTTP.
- [ ] Rozhodnout o podpisu repozitáře (vlastní GPG klíč) a ověřit, jak se starý apt 0.7.20 chová k nepodepsanému.
- [ ] Nastavit hodiny na telefonu (při testu bylo datum 1. 1. 2009).
- [ ] `chown` souborů z `scp` (patří `root`, protože se připojujeme jako root), případně připojení jako `user`.
- [ ] Doplnit `PATH` o sbin trvale i pro SSH relace (hotovo jen pro login shell: `/etc/profile.d/sbin-path.sh`).
- [ ] Zkusit `make build deb` pro jinou verzi WordGrinderu (ověřena jen 0.8), případně 0.9 (Luau, C++).
- [ ] `maemo-g++` wrapper pro C++ (zatím jen `maemo-gcc` pro C).
- [ ] htop3: balíček je sestavený (samostatný `htop3` vedle systémového 0.8.3, obálka s `-d 50` a `HTOPRC`),
  zbývá ho nainstalovat na N900 (`make -C apps/htop install`) a ověřit menu, obálku a odinstalaci.
  Viz [apps/htop/htop.md](apps/htop/htop.md). Nový htop je 2,4× náročnější na procesor.
- [ ] **Roadmapa e-mail / feedy / kontakty a kalendář / rádio:** plán je v [DOC/roadmap.md](DOC/roadmap.md). Čeká na tvá rozhodnutí
  (sekce 8): poskytovatelé, umístění brány, pořadí fází, jazyk pro nativní aplikaci.
- [ ] **curl a git s moderním HTTPS (priorita):** balíčky `curl` (750 kB) a `git` (10 MB, nahradí `git 1.6.2-1`)
  jsou nainstalované a ověřené na N900 (klon `nokia-n900-notes` přes HTTPS za 126 s, 19 příkazů gitu OK).
  Zbývá: odinstalace/návrat ke `git 1.6.2`, `git push` přes HTTPS s tokenem, SSH klient pro `git@github.com:`. Viz [apps/curl/curl.md](apps/curl/curl.md),
  [apps/git/git.md](apps/git/git.md).
- [ ] **cmatrix, cbonsai, tty-clock:** balíčky jsou sestavené (22 kB, 95 kB, 10,5 kB). Zbývá nainstalovat na N900 a ověřit
  spouštěče v menu (`cbonsai-live`), `man`, chování na displeji. Viz [apps/cmatrix/cmatrix.md](apps/cmatrix/cmatrix.md),
  [apps/cbonsai/cbonsai.md](apps/cbonsai/cbonsai.md), [apps/tty-clock/tty-clock.md](apps/tty-clock/tty-clock.md).
- [ ] Zafixovat SHA-256 zdrojových tarballů (curl, mbedTLS, zlib, git) v build skriptech.
- [ ] `wget` s moderním TLS (nebo upravit skripty, aby volaly `curl`).
- [ ] Obalit volání `workshop exec` příkazem `timeout -k` v `mk/common.mk`: `exec` se po dokončení dlouhých
  buildů občas nevrátí (potvrzeno u toolchain, htop a curl).
- [ ] Další aplikace v `apps/<app>/` (kandidáty vybrat).
- [ ] Python 3.11: přepsat na armel a glibc 2.5, vlastní OpenSSL (SDK má jen 0.9.8n). Viz [README.md](README.md).

## Hotovo

- [x] Workshop `n900`, cross-toolchain armel, sysroot z Fremantle SDK (`maemo.plan9.de`).
- [x] `hello` přeložen a spuštěn na N900.
- [x] Všechny aplikace (wordgrinder, htop, curl, git, cmatrix, cbonsai, tty-clock) používají sdílené `mk/app.mk`
  a `scripts/debpack.sh`; po převodu vycházejí balíčky shodně (metadata i seznamy souborů).
- [x] SSH klíčem přes alias `n900`, `make push` s automatickým vytvořením složky.
- [x] WordGrinder 0.8: build, `.deb`, instalace a spuštění na N900.
- [x] `Makefile` v kořeni i v `apps/wordgrinder/`, sdílená část v `mk/common.mk`.
