# WireGuard VPN in user space (wireguard-go + wg) for Maemo 5: the kernel 2.6.28 has no WireGuard module.
# Targets and conventions: ../../mk/app.mk. Needs the Go toolchain of apps/go (make -C apps/go build).
override APP     := wireguard-go
VERSION ?= 0.0.20250522
REV     ?= 1maemo1
RUN_CMD := /usr/bin/wireguard-go --version | head -1
include ../../mk/app.mk
