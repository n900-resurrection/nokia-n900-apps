# Control of the Maemo 5 development environment (Workshop "n900").
# Runs on the host, the commands execute inside the container. See DOC/workshop-crosscompile.md.
# The shared part (settings from .env, colours, help) lives in mk/common.mk, which also
# describes the conventions. Each application has its own Makefile in apps/<app>/.

include mk/common.mk

TARGETS := help up down status enter toolchain sysroot hello wordgrinder htop push clean distclean
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
