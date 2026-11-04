# WordGrinder for Maemo 5: build, package and install on the N900.
# Run on the host (`make -C apps/wordgrinder <target>` or `cd apps/wordgrinder && make`);
# building and packaging happen inside the Workshop. The shared part is ../../mk/common.mk.

include ../../mk/common.mk

APP     := wordgrinder
VERSION ?= 0.8
REV     ?= 1maemo1
DEBFILE := $(APP)_$(VERSION)-$(REV)_armel.deb

TARGETS := help build deb info push install remove run clean
.PHONY: $(TARGETS)

BUILD := Build the binary in the workshop (VERSION=0.8) into build/out/
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
	ssh $(DEVICE) dpkg -r $(APP)

RUN := Run WordGrinder on the N900 over ssh (TERM=xterm)
run:
	ssh -t $(DEVICE) 'TERM=xterm /usr/bin/$(APP)'

CLEAN := Remove the outputs of this application from build/
clean:
	rm -rf $(ROOT)/build/out/$(APP)-* $(ROOT)/build/obj/$(APP)-* $(ROOT)/build/deb
