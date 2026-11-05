# Python 3.11 pro N900

Cross-překlad CPython 3.11 pro Maemo 5 (armel, glibc 2.5.1, jádro 2.6.28). Opravuje chyby původního
[Python_3.11_on_N900](https://github.com/elPytel/Python_3.11_on_N900), viz [DOC/python3-repo-review.md](../../DOC/python3-repo-review.md).

## Použití
```sh
make -C apps/openssl build     # jednou (statický OpenSSL 3.5), zlib a ncurses se berou z apps/curl a apps/mutt
make -C apps/python3 install   # přeloží, zabalí a nainstaluje balíček python3.11
make -C apps/python3 test      # testy na telefonu
```
Na telefonu: `python3` (odkaz v `/usr/bin`, strom v `/opt/python3`). Systémový `python` 2.5, na kterém visí aplikace Hildon (například mutt-hildon), se
nemění.

## Co obsahuje
- `ssl` s OpenSSL 3.5 (statický, TLS 1.3); certifikáty z balíčku `curl` (`sitecustomize.py` nastaví `SSL_CERT_FILE`),
- `sqlite3` s vlastním SQLite 3.50 (systémový 3.6 je pro Python 3.11 příliš starý),
- `zlib`, `curses` a `curses.panel` (wide, statický ncursesw), `socket`, `threading`, `subprocess`, `pty` a ostatní standardní knihovna,
- bajtkód je předkompilovaný při sestavení (jinak by první spuštění na pomalém procesoru trvalo dlouho a `/opt` nemusí být zapisovatelný).

## Ověřeno na telefonu
`make -C apps/python3 test` (20 testů) a ukázkový program [src/python3/hello/hello.py](../../src/python3/hello/hello.py): vypíše verzi, SQLite, stáhne
`https://api.github.com/zen` přes TLS 1.3 (0,7 s) a spočítá 300 000 čtverců (0,7 s); celé spuštění včetně importů trvá asi 3 s.
Balíček má 19 MB (rozbaleno 55 MB v `/opt`, který je na oddílu `/home`, ne na malém rootfs).

## Chybí
`readline` (REPL bez historie a editace řádku), `ctypes` (libffi), `tkinter`, `bz2`, `lzma`, `uuid`, `gdbm`. Postupně podle potřeby.
`pip`: `python3 -m ensurepip` (kola jsou součástí knihovny), potom `python3 -m pip install ...`; čistě pythonové balíčky půjdou, balíčky s C kódem ne.

## Jak je to řešené
Ve skriptu `build.sh` jsou komentáře ke každé volbě. Hlavní body: obal `scripts/maemo-gcc` + sysroot SDK, nativní "build python" stejné verze
(`--with-build-python`), bez PGO, `ac_cv_buggy_getaddrinfo=no` (IPv6 zůstane), `ac_cv_file__dev_ptmx=yes`, pkg-config vypnutý (`CURSES_*`, `LIBSQLITE3_*` zadané ručně).
