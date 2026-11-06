# Control of the Maemo 5 development environment (Workshop "n900").
# Runs on the host, the commands execute inside the container. See DOC/workshop-crosscompile.md.
# The shared part (settings from .env, colours, help) lives in mk/common.mk, which also
# describes the conventions. Each application has its own Makefile in apps/<app>/.

include mk/common.mk

# Every directory apps/<app> with a Makefile is a target of the same name (make curl = make -C apps/curl build);
# ACTION selects another target of the application: make curl ACTION=deb. Descriptions: variables below, or a default.
APPS := $(sort $(notdir $(patsubst %/,%,$(dir $(wildcard apps/*/Makefile)))))
ACTION ?= build
TARGETS := help up down status enter toolchain sysroot hello $(APPS) debs repo test hildon-overlay hildon-run emulator push clean distclean
.PHONY: $(TARGETS)

define APP_RULE
$(call uc,$(1)) ?= Build $(1) (more: make -C apps/$(1))
$(1):
	$$(MAKE) -C apps/$(1) $$(ACTION)
endef
$(foreach a,$(APPS),$(eval $(call APP_RULE,$(a))))

# `make debs` builds the .deb of every application that has a package.sh and skips the ones that are up to date (stamps in
# build/stamps; the DEPS of apps/<app>/Makefile are brought up to date first). APP selects some: make debs APP="curl git"
# Preview without building: make -n debs. With INSTALL=1 the packages are also installed on the phone.
# (The command line APP="a b" reaches the sub-makes too; the Makefiles of the applications use `override APP :=` so that it cannot change their APP.)
DEBAPPS := $(foreach a,$(or $(APP),$(APPS)),$(if $(wildcard apps/$(a)/package.sh),$(a)))
DEBS := Build the .deb packages of all apps (APP="a b" selects; up to date ones are skipped; INSTALL=1 installs too)
REPO := Build the apt repository in ./n900-repository from the current .deb of every app (runs make debs first; see DOC/apt-repo.md)
repo: debs
	$(INSIDE) /project/scripts/mkrepo.sh $(foreach a,$(DEBAPPS),build/deb/$(shell $(MAKE) --no-print-directory -s -C apps/$(a) debfile))

debs:
	@for a in $(DEBAPPS); do printf '\n$(BOLD)== %s$(RESET)\n' $$a; $(MAKE) --no-print-directory -C apps/$$a $(if $(INSTALL),install,deb) || exit 1; done

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
HTOP := Build htop (more: make -C apps/htop)
CURL := Build curl with TLS 1.3 (more: make -C apps/curl)
GIT := Build git with HTTPS (needs curl, more: make -C apps/git)
CMATRIX := Build cmatrix (more: make -C apps/cmatrix)
CBONSAI := Build cbonsai (more: make -C apps/cbonsai)
SFEED := Build sfeed (more: make -C apps/sfeed)
RANGER := Package ranger, the console file manager (needs python3, more: make -C apps/ranger)
MUTT := Build Mutt (more: make -C apps/mutt)
MUTT-HILDON := Package the Hildon GUI over Mutt (more: make -C apps/mutt-hildon)
CAMEL-LITE := Build camel-lite (Modest mail library) with OpenSSL 3 (more: make -C apps/camel-lite)
PYTHON3 := Cross-build Python 3.11 (more: make -C apps/python3)
HILDON-OVERLAY := Copy the Hildon theme, fonts and icons from the phone into ./sysroot (once; for hildon-run)
hildon-overlay:
	DEVICE=$(DEVICE) scripts/hildon-overlay.sh

EMULATOR := Start the emulated Fremantle desktop (top bar, launcher, task switching): make emulator (VNC on port 5999 of the Workshop, address is printed)
emulator:
	$(INSIDE) env VNC=$(or $(VNC),1) FRESH=1 FOREGROUND=1 /project/scripts/hildon-session.sh

EMULATOR-STOP := End a running emulator session (screen, VNC, window manager, bar, programs)
emulator-stop:
	$(INSIDE) env STOP=1 /project/scripts/hildon-session.sh

HILDON-RUN := Show a GTK2/Hildon program on a virtual 800x480 screen: make hildon-run [APP=mutt-hildon | SCRIPT=src/python3/hildon/proof.py] [SHOT=build/shot.png] [VNC=1] [PY2=1 for Python 2.5]
SCRIPT ?= src/python3/hildon/proof.py
# SCRIPT=apps/<app>/... of an application that has apps/<app>/hildon-run.sh means APP=<app> (it needs the demo home)
ifeq ($(APP),)
SCRIPTAPP := $(word 2,$(subst /, ,$(SCRIPT)))
ifneq ($(and $(filter apps/%,$(SCRIPT)),$(wildcard apps/$(SCRIPTAPP)/hildon-run.sh)),)
APP := $(SCRIPTAPP)
endif
endif
hildon-run:
	$(INSIDE) env SHOT=$(SHOT) VNC=$(VNC) PY2=$(PY2) APP=$(APP) HILDON_DEVSHELL_SCRIPT=$(DEVSHELL_SCRIPT) HILDON_DEVSHELL_DEBUG=$(DEVSHELL_DEBUG) /project/scripts/hildon-run.sh $(if $(APP),,/project/$(SCRIPT))

QUICKJS := Cross-build QuickJS, JavaScript runtime for yt-dlp (more: make -C apps/quickjs)
MSMTP := Build msmtp (more: make -C apps/msmtp)
JQ := Build jq (more: make -C apps/jq)
TEST := Run the tests of all apps on the N900 (apps/*/test.sh); the packages must be installed
test:
	@fail=0; for t in $(ROOT)/apps/*/test.sh; do a=$$(basename $$(dirname $$t)); printf '\n$(BOLD)== %s$(RESET)\n' $$a; $(MAKE) --no-print-directory -C apps/$$a test || fail=$$((fail+1)); done; \
	if [ $$fail -eq 0 ]; then printf '\n$(GREEN)All test suites passed$(RESET)\n'; else printf '\n$(RED)%s test suite(s) failed$(RESET)\n' $$fail; exit 1; fi

TTY-CLOCK := Build tty-clock (more: make -C apps/tty-clock)
OPENSSL := Build static OpenSSL 3 (dependency) (more: make -C apps/openssl)
NTP-SYNC := Check the ntp-sync script (more: make -C apps/ntp-sync)
GO := Download Go and build the Go hello example (more: make -C apps/go)
BASH := Build Bash 5 (more: make -C apps/bash)
BUSYBOX := Build BusyBox 1.37 (more: make -C apps/busybox)
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
