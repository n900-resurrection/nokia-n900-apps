# BusyBox 1.37 pro Maemo 5

Balíček `busybox37`, vedle systémového `busybox-power` 1.23.1. Nepřepisuje `/bin/busybox` ani `/bin/sh`.

## Sestavení a instalace
```sh
make -C apps/busybox build
make -C apps/busybox install      # deb se sestaví sám, když je zastaralý
```
Instaluje do `/opt/busybox37`: binárka `bin/busybox`, 383 odkazů na applety v `bin/`, odkaz `/usr/bin/busybox37`.

## Použití
```sh
busybox37 awk 'BEGIN{print 2^10}'           # jeden applet
PATH=/opt/busybox37/bin:$PATH               # nové applety před systémovými (jen pro tento shell)
```
Natrvalo jen pro sebe: řádek s `PATH=...` do `~/.bashrc` (nebo `~/.profile`). **Nedávej to globálně**
do `/etc/profile.d`: systémové skripty Maemo (init, icd2, hooky) by pak používaly jiné applety a mohly se rozbít.
Pro nové skripty stačí `export PATH=/opt/busybox37/bin:$PATH` na jejich začátku.

## Konfigurace
Upstream `defconfig` + úpravy v [config.sh](config.sh). Vypnuto, protože chybí hlavičky, knihovny nebo volání jádra:

| Vypnuto | Důvod |
|---|---|
| `ip`, `ipaddr`, `iplink`, `iproute`, `iprule`, `iptunnel`, `ipneigh`, `tc` | hlavičky netlinku (`linux/can/netlink.h`, `IFA_F_DADFAILED`) jsou v SDK starší |
| `setpriv`, `run-init` | `linux/capability.h` z jádra koliduje s typy glibc |
| `nsenter`, `unshare` | `setns()` neexistuje v glibc 2.5 ani v jádře 2.6.28 |
| `sync -f` (`syncfs`) | totéž |
| `seedrng` | potřebuje `CLOCK_BOOTTIME` (jádro 2.6.39) a `getrandom()` |
| `nslookup` | v glibc 2.5 nejsou `__ns_*` funkce, které použije |
| SHA1/SHA256 HWACCEL | instrukce x86 |
| `wget` přes HTTPS | vestavěný `ssl_client` umí jen TLS 1.2, použij `curl` |

- Dynamicky linkovaný (statický glibc nezvládne DNS a uživatele bez sdílených knihoven stejné verze).
- [shims.c](shims.c): `utimensat()` a `futimens()` (syscall 348 na ARM), které glibc 2.5 nemá; potřebuje je `touch`.
- `UTIME_NOW`/`UTIME_OMIT` se doplňují přes `-D` v `EXTRA_CFLAGS`.

## Testy
`make -C apps/busybox test` ([test.sh](test.sh)): 21 prošlo, 0 selhalo, včetně souhry s `bash5`.
Ověřeno ručně: `touch -d`, `awk`, `sed`, `tar`, `sha256sum`, `ash`, `wget` přes HTTP.
