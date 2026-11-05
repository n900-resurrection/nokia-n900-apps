# Control of the Maemo 5 development environment (Workshop "n900").
# Runs on the host, the commands execute inside the container. See DOC/workshop-crosscompile.md.
# The shared part (settings from .env, colours, help) lives in mk/common.mk, which also
# describes the conventions. Each application has its own Makefile in apps/<app>/.

include mk/common.mk

TARGETS := help up down status enter toolchain sysroot hello wordgrinder htop curl git cmatrix cbonsai tty-clock openssl ntp-sync go bash busybox jq mutt msmtp sfeed test mutt-hildon push clean distclean
.PHONY: $(TARGETS)

UP := Create and start the workshop (first run)
up:
	$(WORKSHOP) launch $(WS)

DOWN := Stop the workshop
down:
	$(WORKSHOP) stop $(WS)

STATUS := Show the workshop status
status:
	$(WORKSHOP) list

ENTER := Open an interactive shell inside the workshop
enter:
	$(WORKSHOP) shell $(WS)

TOOLCHAIN := Install the armel cross toolchain and qemu-user
toolchain:
	$(WSRUN) toolchain

SYSROOT := Download the Fremantle SDK sysroot into ./sysroot
sysroot:
	$(WSRUN) sysroot

HELLO := Build and run hello.c (qemu-user, glibc 2.5)
hello:
	$(WSRUN) hello

WORDGRINDER := Build WordGrinder (more: make -C apps/wordgrinder)
wordgrinder:
	$(MAKE) -C apps/wordgrinder build

HTOP := Build htop (more: make -C apps/htop)
htop:
	$(MAKE) -C apps/htop build

CURL := Build curl with TLS 1.3 (more: make -C apps/curl)
curl:
	$(MAKE) -C apps/curl build

GIT := Build git with HTTPS (needs curl, more: make -C apps/git)
git:
	$(MAKE) -C apps/git build

CMATRIX := Build cmatrix (more: make -C apps/cmatrix)
cmatrix:
	$(MAKE) -C apps/cmatrix build

CBONSAI := Build cbonsai (more: make -C apps/cbonsai)
cbonsai:
	$(MAKE) -C apps/cbonsai build

SFEED := Build sfeed (more: make -C apps/sfeed)
sfeed:
	$(MAKE) -C apps/sfeed build

MUTT := Build Mutt (more: make -C apps/mutt)
mutt:
	$(MAKE) -C apps/mutt build

MUTT-HILDON := Package the Hildon GUI over Mutt (more: make -C apps/mutt-hildon)
mutt-hildon:
	$(MAKE) -C apps/mutt-hildon build

MSMTP := Build msmtp (more: make -C apps/msmtp)
msmtp:
	$(MAKE) -C apps/msmtp build

JQ := Build jq (more: make -C apps/jq)
jq:
	$(MAKE) -C apps/jq build

TEST := Run the tests of all apps on the N900 (apps/*/test.sh); the packages must be installed
test:
	@fail=0; for t in $(ROOT)/apps/*/test.sh; do a=$$(basename $$(dirname $$t)); printf '\n$(BOLD)== %s$(RESET)\n' $$a; $(MAKE) --no-print-directory -C apps/$$a test || fail=$$((fail+1)); done; \
	if [ $$fail -eq 0 ]; then printf '\n$(GREEN)All test suites passed$(RESET)\n'; else printf '\n$(RED)%s test suite(s) failed$(RESET)\n' $$fail; exit 1; fi

TTY-CLOCK := Build tty-clock (more: make -C apps/tty-clock)
tty-clock:
	$(MAKE) -C apps/tty-clock build

OPENSSL := Build static OpenSSL 3 (dependency) (more: make -C apps/openssl)
openssl:
	$(MAKE) -C apps/openssl build

NTP-SYNC := Check the ntp-sync script (more: make -C apps/ntp-sync)
ntp-sync:
	$(MAKE) -C apps/ntp-sync build

GO := Download Go and build the Go hello example (more: make -C apps/go)
go:
	$(MAKE) -C apps/go build

BASH := Build Bash 5 (more: make -C apps/bash)
bash:
	$(MAKE) -C apps/bash build

BUSYBOX := Build BusyBox 1.37 (more: make -C apps/busybox)
busybox:
	$(MAKE) -C apps/busybox build

PUSH := Copy FILE to the N900 (creates the target dir): make push [DEVICE=n900] [FILE=build/hello]
push:
	@test -n "$(DEVICE)" || { printf '$(RED)Set DEVICE=user@ip (in .env or on the command line)$(RESET)\n'; exit 1; }
	ssh $(DEVICE) mkdir -p $(DEST)
	scp $(FILE) $(DEVICE):$(DEST)

CLEAN := Remove ./build
clean:
	rm -rf build

DISTCLEAN := Also remove ./sysroot and ./downloads
distclean: clean
	rm -rf sysroot downloads
