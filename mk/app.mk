# Generic Makefile for an application in apps/<app>/. The app Makefile only sets variables and
# includes this file:
#
#   override APP := tty-clock                  # directory name under apps/ (build.sh, package.sh); `override` keeps the APP="a b" of
#                                              # the root Makefile (make debs APP="a b") from changing it
#   VERSION  ?= 2.3                            # upstream version, passed to the scripts as VERSION
#   PKG      := tty-clock                      # optional, package name (default: APP)
#   REV      ?= 1maemo1                        # optional, package revision
#   RUN_CMD  := TERM=xterm /usr/bin/tty-clock  # command run on the device by `make run`
#   EMU_BIN  := /project/build/out/...         # optional, binary for `make emu` (default: build/out/<APP>-<VERSION>/<APP>)
#   DEPS     := openssl curl                   # optional, apps (apps/<dep>) that must be built first; a rebuilt dependency
#                                              # makes this application out of date
#   DEBFILE  := name_1.0-1maemo1_armel.deb     # optional, when the package file name differs from PKG_VERSION-REV_armel.deb
#   include ../../mk/app.mk
#
# See common.mk for the conventions (description variables, colours, .env).

include $(dir $(lastword $(MAKEFILE_LIST)))common.mk

PKG     ?= $(APP)
REV     ?= 1maemo1
DEBFILE ?= $(PKG)_$(VERSION)-$(REV)_armel.deb
DEPS    ?=

TARGETS := help build deb debfile info push install remove run test emu clean
.PHONY: $(TARGETS) stamp FORCE
FORCE:

# Build stamp: `make deb` (and so push/install) rebuilds only when the build inputs are newer than
# the last successful build: build.sh and any other file in the app directory except package.sh, test.sh, icon.png,
# docs and the Makefile, and the stamps of the DEPS applications. `make build` always rebuilds.
# build/stamps/<app>.built (without version) is the stamp other applications depend on.
STAMP  := $(ROOT)/build/stamps/$(APP)-$(VERSION).built
ASTAMP := $(ROOT)/build/stamps/$(APP).built
SRCS   := $(filter-out %/package.sh %/test.sh %/LICENSE %.md %/Makefile %/icon.png,$(wildcard $(ROOT)/apps/$(APP)/*))
DEPSTAMPS := $(foreach d,$(DEPS),$(ROOT)/build/stamps/$(d).built)

BUILD := Build $(APP) $(VERSION) in the workshop into build/out/ (always)
build:
	$(INSIDE) bash -c 'VERSION=$(VERSION) /project/apps/$(APP)/build.sh'
	@mkdir -p $(dir $(STAMP)) && touch $(STAMP) $(ASTAMP)

# A dependency is brought up to date by a sub-make on every run (FORCE); the stamp file changes only when it was rebuilt,
# and only then are the applications depending on it rebuilt.
$(DEPSTAMPS): $(ROOT)/build/stamps/%.built: FORCE
	@$(MAKE) --no-print-directory -C $(ROOT)/apps/$* stamp

$(STAMP): $(SRCS) $(DEPSTAMPS)
	$(MAKE) build

stamp: $(STAMP)

# Package stamp: package.sh runs when the build is newer, package.sh changed or the .deb is missing.
PSTAMP := $(ROOT)/build/stamps/$(APP)-$(VERSION)-$(REV).packaged
$(PSTAMP): $(STAMP) $(ROOT)/scripts/debpack.sh $(wildcard $(ROOT)/apps/$(APP)/package.sh $(ROOT)/apps/$(APP)/icon.png) $(if $(wildcard $(ROOT)/build/deb/$(DEBFILE)),,FORCE)
	$(INSIDE) bash -c 'VERSION=$(VERSION) REV=$(REV) /project/apps/$(APP)/package.sh'
	@touch $(PSTAMP)

DEB := Create the .deb (armel) in build/deb/ (builds first when out of date)
deb: $(PSTAMP)

INFO := Show the package metadata and contents (builds the .deb first)
debfile:
	@echo $(DEBFILE)

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
	rm -rf $(ROOT)/build/stamps/$(APP)-* $(ASTAMP) $(ROOT)/build/out/$(APP)-* $(ROOT)/build/obj/$(APP)-* $(ROOT)/build/deb/stage-$(PKG) $(ROOT)/build/deb/$(PKG)_*
