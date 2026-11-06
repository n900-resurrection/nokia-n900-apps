# Python 3.11 for Maemo 5 (own OpenSSL 3 for ssl, own SQLite). Targets and conventions: ../../mk/app.mk
override APP     := python3
DEPS    := openssl curl mutt
VERSION ?= 3.11.18
PKG     := python3.11
REV     ?= 2maemo1
RUN_CMD := /usr/bin/python3 -c 'import sys; print(sys.version)'
EMU_BIN := /project/build/out/python3-$(VERSION)/root/opt/python3/bin/python3.11
include ../../mk/app.mk
