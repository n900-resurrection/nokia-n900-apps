# tmux (terminal multiplexer) for Maemo 5. Targets and conventions: ../../mk/app.mk
override APP     := tmux
VERSION ?= 3.8
REV     ?= 1maemo1
RUN_CMD := TERM=xterm /usr/bin/tmux -V
include ../../mk/app.mk

# Emulation test under qemu-user (needs `make locale-overlay` once); the phone is not used.
QEMU-TEST := Test tmux under qemu-user with a UTF-8 locale (not on the phone)
.PHONY: qemu-test
qemu-test:
	$(INSIDE) /project/apps/tmux/qemu-test.sh
