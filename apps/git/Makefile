# Modern git (HTTPS over TLS 1.2/1.3) for Maemo 5: build, package and install on the N900.
# Run on the host (`make -C apps/git <target>`); building and packaging happen inside the Workshop.
# The package git replaces the old git 1.6.2-1 and depends on the curl package (CA bundle).
# Shared part: ../../mk/common.mk.

include ../../mk/common.mk

APP     := git
VERSION ?= 2.56.0
REV     ?= 1maemo1
DEBFILE := $(APP)_$(VERSION)-$(REV)_armel.deb

TARGETS := help build deb info push install remove run clean
.PHONY: $(TARGETS)

BUILD := Build git in the workshop (GIT_VERSION=2.56.0, needs the curl build)
build:
	$(INSIDE) bash -c 'GIT_VERSION=$(VERSION) /project/apps/$(APP)/build.sh'

DEB := Create the .deb (armel) in build/deb/ (needs make build)
deb:
	$(INSIDE) bash -c 'GIT_VERSION=$(VERSION) REV=$(REV) /project/apps/$(APP)/package.sh'

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

INSTALL := Install the .deb on the N900 (dpkg -i, upgrades git 1.6.2, changes the phone)
install: push
	ssh $(DEVICE) dpkg -i $(DEST)$(DEBFILE)

REMOVE := Remove the package from the N900 (dpkg -r)
remove:
	@test -n "$(DEVICE)" || { printf '$(RED)Set DEVICE$(RESET)\n'; exit 1; }
	ssh $(DEVICE) dpkg -r $(APP)

RUN := Test git on the N900: version and ls-remote over HTTPS (needs the installed packages)
run:
	ssh $(DEVICE) '/usr/bin/git --version && /usr/bin/git ls-remote https://github.com/octocat/Hello-World.git HEAD'

CLEAN := Remove the outputs of this application from build/
clean:
	rm -rf $(ROOT)/build/out/$(APP)-* $(ROOT)/build/obj/$(APP)-* $(ROOT)/build/deb/stage-$(APP) $(ROOT)/build/deb/$(APP)_*
