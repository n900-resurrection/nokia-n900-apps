# camel-lite (mail library of Modest) with OpenSSL 3, test install into /opt/camel-lite3. Conventions: ../../mk/app.mk
override APP     := camel-lite
DEPS    := openssl
VERSION ?= 1.1.92cssu7
PKG     := camel-lite-ssl3
REV     ?= 2maemo1
RUN_CMD := /opt/camel-lite3/bin/camel-tlstest imap.centrum.cz 993
include ../../mk/app.mk
