# curl 8.23 s TLS 1.3 na Maemo 5

Stav k 2026-11-04. Build a balení: [Makefile](Makefile) (`make curl` v kořeni, `make -C apps/curl <cil>`).
Balíček `curl` je **nainstalovaný na N900** (`curl 8.23.0-1maemo1`, `/usr/bin/curl -> ../../opt/curl/bin/curl`)
a používá ho `git` pro HTTPS (vestavěná cesta k CA balíku `/opt/curl/etc/ssl/cacert.pem` funguje).

## Proč

Systém má OpenSSL 0.9.8n (jen TLS 1.0), libcurl 7.18 a wget 1.10. S moderními servery (GitHub, Wikipedia)
se nedomluví ani s platnými certifikáty (`tlsv1 alert protocol version`). Řešení: vlastní `curl` s moderní
TLS knihovnou, slinkovaný staticky.

## Co je uvnitř

| Součást | Verze | Poznámka |
|---|---|---|
| curl | 8.23.0 | `--without-libpsl/brotli/zstd/idn2/nghttp2`, jen HTTP(S), FTP(S), file, WS(S) |
| mbedTLS | 3.6.7 | TLS 1.2 a 1.3, statické; zvoleno místo OpenSSL 3 kvůli velikosti a jednoduchému buildu |
| zlib | 1.3.2 | vlastní statický, curl 8 chce zlib ≥ 1.2.5.2, SDK má 1.2.3 |
| CA balík | Mozilla, z `curl.se/ca/cacert.pem` | `/opt/curl/etc/ssl/cacert.pem`, **neaktualizuje se sám** |

Výsledek: 1,2 MB, `NEEDED`: librt, libpthread, libc, nejvyšší symbol `GLIBC_2.7` (`eventfd`, telefon ho má:
eglibc 2.5.1-1eglibc27 exportuje verze 2.4, 2.5 a 2.7). Proto `Depends: libc6 (>= 2.5.1-1eglibc27)`.

## Ověřeno na N900 (2026-11-04)

- `curl --version`: `mbedTLS/3.6.7 zlib/1.3.2`
- `https://github.com`: HTTP 200, certifikát ověřen
- `https://example.com`: **TLSv1.3**, `TLS_CHACHA20_POLY1305_SHA256`
- stažení `README.md` z `raw.githubusercontent.com`

## Co se muselo vyřešit

| Problém | Řešení |
|---|---|
| mbedTLS `make install` staví i ukázkové programy a padá | knihovny a hlavičky se kopírují ručně |
| `--without-ssl` společně s `--with-mbedtls` | konflikt přepínačů, `--without-ssl` pryč |
| curl chce zlib ≥ 1.2.5.2 | vlastní statický zlib (`build/deps/zlib-*`) |
| přesto se bral starý `zlib.h` ze sysrootu | `scripts/maemo-gcc` ignoroval `-I`, protože curl dává tutéž cestu jako `-isystem`; wrapper má nově `MAEMO_DEPS` a dává cesty jako `-isystem` **před** sysroot |
| **`curl` na telefonu visí při startu** | mbedTLS 3.6 čte bez `getrandom()` raději `/dev/random`, které na jádře 2.6.28 blokuje. Upstream: „may block needlessly on Linux ≤ 5.6“. Řešení: `-include mbedtls-urandom.h` s `MBEDTLS_PLATFORM_DEV_RANDOM "/dev/urandom"` |

Poslední bod se v emulátoru (`qemu-arm`) **neprojevil**, protože hostitelské jádro `getrandom()` má. Odhalil ho
až skutečný telefon (čekání v `random_read`, zjištěno z `/proc/<pid>/wchan`).

## Bezpečnostní poznámky

- `/dev/urandom` místo `/dev/random`: neblokuje a na běžícím telefonu je zdroj entropie dostatečný. Pro
  cokoli, co se spouští hned po startu systému, by to bylo nevhodné. Důvod je v `mbedtls-urandom.h`.
- CA balík je snapshot ze dne buildu. Aktualizace: `curl -o /opt/curl/etc/ssl/cacert.pem https://curl.se/ca/cacert.pem`
  (po instalaci balíčku). Do verzovaného repa se balík nedává, stahuje se při buildu.
- Zdrojové tarbally se stahují z oficiálních míst a skript vypíše jejich SHA-256. Hashe zatím **nejsou
  zafixované**; při prvním stažení je tedy potřeba jim věřit.
- Licence: curl (curl license), mbedTLS (Apache-2.0 nebo GPL-2.0+), zlib (zlib license). Texty jsou v balíčku.

## Příkazy

```bash
make curl                        # nebo make -C apps/curl build
make -C apps/curl deb            # build/deb/curl_8.23.0-1maemo1_armel.deb (750 kB)
make -C apps/curl install        # nainstaluje na N900 (dpkg -i), mění telefon
make -C apps/curl run            # test HTTPS na GitHub z telefonu
```

## Co zbývá

- Zafixovat SHA-256 zdrojových balíčků.
- Dev balíček s `libcurl.a` a hlavičkami? Zatím je jen v build stromu (používá ho git).
- `wget` s moderním TLS (curl ho nenahradí v skriptech, které volají `wget`).
