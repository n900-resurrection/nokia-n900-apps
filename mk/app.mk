# Generic Makefile for an application in apps/<app>/. The app Makefile only sets variables and
# includes this file:
#
#   APP      := tty-clock                      # directory name under apps/ (build.sh, package.sh)
#   VERSION  ?= 2.3                            # upstream version, passed to the scripts as VERSION
#   PKG      := tty-clock                      # optional, package name (default: APP)
#   REV      ?= 1maemo1                        # optional, package revision
#   RUN_CMD  := TERM=xterm /usr/bin/tty-clock  # command run on the device by `make run`
#   (`make emu` runs build/out/<APP>-<VERSION>/<APP> in the workshop under qemu-user, no phone needed)
#   include ../../mk/app.mk
#
# Older applications (wordgrinder, htop, curl, git) have their own Makefile with the same targets.
# See common.mk for the conventions (description variables, colours, .env).

include $(dir $(lastword $(MAKEFILE_LIST)))common.mk

PKG     ?= $(APP)
REV     ?= 1maemo1
DEBFILE := $(PKG)_$(VERSION)-$(REV)_armel.deb

TARGETS := help build deb info push install remove run emu clean
.PHONY: $(TARGETS)

BUILD := Build $(APP) $(VERSION) in the workshop into build/out/
build:
	$(INSIDE) bash -c 'VERSION=$(VERSION) /project/apps/$(APP)/build.sh'

DEB := Create the .deb (armel) in build/deb/ (needs make build)
deb:
	$(INSIDE) bash -c 'VERSION=$(VERSION) REV=$(REV) /project/apps/$(APP)/package.sh'

INFO := Show the package metadata and contents
info:
	@test -f $(ROOT)/build/deb/$(DEBFILE) || { printf '$(RED)Missing build/deb/$(DEBFILE), run make deb$(RESET)\n'; exit 1; }
	dpkg-deb -I $(ROOT)/build/deb/$(DEBFILE)
	dpkg-deb -c $(ROOT)/build/deb/$(DEBFILE)

PUSH := Copy the .deb to the N900 into DEST (creates the directory)
push:
	@test -n "$(DEVICE)" || { printf '$(RED)Set DEVICE (in .env or on the command line)$(RESET)\n'; exit 1; }
	@test -f $(ROOT)/build/deb/$(DEBFILE) || { printf '$(RED)Missing build/deb/$(DEBFILE), run make deb$(RESET)\n'; exit 1; }
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

# TERM=xterm like on the device: the sysroot (and the phone) has no terminfo for xterm-256color.
# EMU_TERM overrides it.
EMU := Run the built binary in the workshop under qemu-user: make emu ARGS=--help
emu:
	$(INSIDE) env LC_ALL=C TERM=$(or $(EMU_TERM),xterm) qemu-arm -L /project/sysroot /project/build/out/$(APP)-$(VERSION)/$(APP) $(ARGS)

CLEAN := Remove the outputs of this application from build/
clean:
	rm -rf $(ROOT)/build/out/$(APP)-* $(ROOT)/build/obj/$(APP)-* $(ROOT)/build/deb/stage-$(PKG) $(ROOT)/build/deb/$(PKG)_*
