# GNU Wget 1.25 with modern TLS (static OpenSSL 3) for Maemo 5. Targets and conventions: ../../mk/app.mk
override APP     := wget
DEPS    := openssl curl
VERSION ?= 1.25.0
RUN_CMD := /usr/bin/wget -q -O - https://curl.se/ | head -c 80
include ../../mk/app.mk
