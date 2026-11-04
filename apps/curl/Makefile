# Modern curl (TLS 1.2/1.3 via mbedTLS) for Maemo 5. Targets and conventions: ../../mk/app.mk
# "make run" tests HTTPS from the phone. "make build" also builds zlib and mbedTLS (static).
APP     := curl
VERSION ?= 8.23.0
RUN_CMD := /usr/bin/curl -sS -o /dev/null -w "http=%{http_code} verify=%{ssl_verify_result}\n" https://github.com
include ../../mk/app.mk
