# Go na Maemo 5

Go se překládá křížově na hostiteli (`make -C apps/go build`), na telefonu se nepřekládá. Výsledek je
statická binárka (`CGO_ENABLED=0`, `GOARM=7`), nepotřebuje glibc 2.5 ani OpenSSL, TLS 1.3 je v Go.

## Ověřeno na N900 (2026-11-05), Go 1.24.13
- Goroutiny, `net/http`, HTTPS na GitHub s TLS 1.3. Ukázka je v `src/go/hello`.
- Jádro 2.6.28 nemá syscall `epoll_pwait` (ARM, přibyl v 2.6.32), runtime Go proto padal s
  `epollwait failed with 38` (ENOSYS). `build.sh` proto v kopii toolchainu změní číslo syscallu
  na `epoll_wait` (252). Bez té úpravy žádný Go program nepoběží.
- CA certifikáty: Go na Maemo žádné nenajde. Spouštět s `SSL_CERT_FILE=/opt/curl/etc/ssl/cacert.pem`.
- CPU je jedno jádro (`NumCPU` = 1): goroutiny běží prokládaně, ne paralelně.

## Neověřeno
Dlouhodobý běh, spotřeba paměti (245 MB RAM), další syscally mimo `net/http` a goroutiny, novější verze Go.
