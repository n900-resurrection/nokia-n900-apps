# msmtp (SMTP client with TLS 1.3, sendmail replacement for Mutt) for Maemo 5. Targets: ../../mk/app.mk
override APP     := msmtp
DEPS    := openssl
VERSION ?= 1.8.34
RUN_CMD := /usr/bin/msmtp --version | head -3
include ../../mk/app.mk
