# Generic Makefile for an application in apps/<app>/. The app Makefile only sets variables and
# includes this file:
#
#   APP      := tty-clock                      # directory name under apps/ (build.sh, package.sh)
#   VERSION  ?= 2.3                            # upstream version, passed to the scripts as VERSION
#   PKG      := tty-clock                      # optional, package name (default: APP)
#   REV      ?= 1maemo1                        # optional, package revision
#   RUN_CMD  := TERM=xterm /usr/bin/tty-clock  # command run on the device by `make run`
#   EMU_BIN  := /project/build/out/...         # optional, binary for `make emu` (default: build/out/<APP>-<VERSION>/<APP>)
#   include ../../mk/app.mk
#
# See common.mk for the conventions (description variables, colours, .env).

include $(dir $(lastword $(MAKEFILE_LIST)))common.mk

PKG     ?= $(APP)
REV     ?= 1maemo1
DEBFILE := $(PKG)_$(VERSION)-$(REV)_armel.deb

TARGETS := help build deb info push install remove run test emu clean
.PHONY: $(TARGETS)

# Build stamp: `make deb` (and so push/install) rebuilds only when the build inputs are newer than
# the last successful build: build.sh and any other file in the app directory except package.sh,
# docs and the Makefile. `make build` always rebuilds.
STAMP := $(ROOT)/build/stamps/$(APP)-$(VERSION).built
SRCS  := $(filter-out %/package.sh %.md %/Makefile,$(wildcard $(ROOT)/apps/$(APP)/*))

BUILD := Build $(APP) $(VERSION) in the workshop into build/out/ (always)
build:
	$(INSIDE) bash -c 'VERSION=$(VERSION) /project/apps/$(APP)/build.sh'
	@mkdir -p $(dir $(STAMP)) && touch $(STAMP)

$(STAMP): $(SRCS)
	$(MAKE) build

DEB := Create the .deb (armel) in build/deb/ (builds first when out of date)
deb: $(STAMP)
	$(INSIDE) bash -c 'VERSION=$(VERSION) REV=$(REV) /project/apps/$(APP)/package.sh'

INFO := Show the package metadata and contents (builds the .deb first)
info: deb
	dpkg-deb -I $(ROOT)/build/deb/$(DEBFILE)
	dpkg-deb -c $(ROOT)/build/deb/$(DEBFILE)

PUSH := Copy the .deb to the N900 into DEST (builds the .deb first, creates the directory)
push: deb
	@test -n "$(DEVICE)" || { printf '$(RED)Set DEVICE (in .env or on the command line)$(RESET)\n'; exit 1; }
	ssh $(DEVICE) mkdir -p $(DEST)
	scp $(ROOT)/build/deb/$(DEBFILE) $(DEVICE):$(DEST)

INSTALL := Install the .deb on the N900 (dpkg -i, changes the phone)
install: push
	ssh $(DEVICE) dpkg -i $(DEST)$(DEBFILE)

REMOVE := Remove the package from the N900 (dpkg -r)
remove:
	@test -n "$(DEVICE)" || { printf '$(RED)Set DEVICE$(RESET)\n'; exit 1; }
	ssh $(DEVICE) dpkg -r $(PKG)

RUN := Run the program on the N900 over ssh
run:
	ssh -t $(DEVICE) '$(RUN_CMD)'

# Tests run ON the phone (the package must be installed): tests/lib.sh + apps/<app>/test.sh are sent
# through one ssh session to a shell. TEST_SHELL can be changed per app (default: sh = busybox ash).
TEST_SHELL ?= sh
TEST := Run apps/$(APP)/test.sh on the N900 (needs the package installed: make install)
test:
	@test -n "$(DEVICE)" || { printf '$(RED)Set DEVICE$(RESET)\n'; exit 1; }
	@test -f $(ROOT)/apps/$(APP)/test.sh || { printf '$(YELLOW)No tests for $(APP) (apps/$(APP)/test.sh)$(RESET)\n'; exit 0; }
	@cat $(ROOT)/tests/lib.sh $(ROOT)/apps/$(APP)/test.sh | ssh -q $(DEVICE) $(TEST_SHELL) -s

# TERM=xterm like on the device: the sysroot (and the phone) has no terminfo for xterm-256color.
# EMU_TERM overrides it.
EMU := Run the built binary in the workshop under qemu-user: make emu ARGS=--help
emu:
	$(INSIDE) env LC_ALL=C TERM=$(or $(EMU_TERM),xterm) qemu-arm -L /project/sysroot $(or $(EMU_BIN),/project/build/out/$(APP)-$(VERSION)/$(APP)) $(ARGS)

CLEAN := Remove the outputs of this application from build/
clean:
	rm -rf $(ROOT)/build/stamps/$(APP)-* $(ROOT)/build/out/$(APP)-* $(ROOT)/build/obj/$(APP)-* $(ROOT)/build/deb/stage-$(PKG) $(ROOT)/build/deb/$(PKG)_*
