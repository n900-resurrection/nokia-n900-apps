# htop 3.x for Maemo 5: build, package and install on the N900 (as the separate package htop3).
# Run on the host (`make -C apps/htop <target>`); building and packaging happen inside the Workshop.
# The system htop 0.8.3 is not touched. Shared part: ../../mk/common.mk.

include ../../mk/common.mk

APP     := htop
PKG     := htop3
VERSION ?= 3.5.3
REV     ?= 1maemo1
DEBFILE := $(PKG)_$(VERSION)-$(REV)_armel.deb

TARGETS := help build deb info push install remove run clean
.PHONY: $(TARGETS)

BUILD := Build htop in the workshop (VERSION=3.5.3) into build/out/
build:
	$(INSIDE) bash -c 'VERSION=$(VERSION) /project/apps/$(APP)/build.sh'

DEB := Create the .deb htop3 (armel) in build/deb/ (needs make build)
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

RUN := Run htop3 on the N900 over ssh (TERM=xterm)
run:
	ssh -t $(DEVICE) 'TERM=xterm /usr/bin/$(PKG)'

CLEAN := Remove the outputs of this application from build/
clean:
	rm -rf $(ROOT)/build/out/$(APP)-* $(ROOT)/build/obj/$(APP)-* $(ROOT)/build/deb/stage-$(PKG) $(ROOT)/build/deb/$(PKG)_*
