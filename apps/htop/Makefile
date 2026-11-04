# htop for Maemo 5: cross-build and a manual trial run on the N900.
# Run on the host (`make -C apps/htop <target>`); building happens inside the Workshop.
# There is no .deb yet: the device already has htop 0.8.3 (package htop), and the packaging
# strategy (upgrade vs. a separate package) is still to be decided, see TODO.md.

include ../../mk/common.mk

APP     := htop
VERSION ?= 3.5.3
# Name of the trial binary on the device, so the system htop 0.8.3 stays untouched
TRIAL   ?= htop3

TARGETS := help build push run clean
.PHONY: $(TARGETS)

BUILD := Build htop in the workshop (VERSION=3.5.3) into build/out/
build:
	$(INSIDE) bash -c 'VERSION=$(VERSION) /project/apps/$(APP)/build.sh'

PUSH := Copy the binary to the N900 as DEST/htop3 (the system htop is not touched)
push:
	@test -n "$(DEVICE)" || { printf '$(RED)Set DEVICE (in .env or on the command line)$(RESET)\n'; exit 1; }
	@test -f $(ROOT)/build/out/$(APP)-$(VERSION)/$(APP) || { printf '$(RED)Missing build output, run make build$(RESET)\n'; exit 1; }
	ssh $(DEVICE) mkdir -p $(DEST)
	scp $(ROOT)/build/out/$(APP)-$(VERSION)/$(APP) $(DEVICE):$(DEST)$(TRIAL)
	ssh $(DEVICE) chmod +x $(DEST)$(TRIAL)

RUN := Run the trial htop on the N900 over ssh (TERM=xterm)
run:
	ssh -t $(DEVICE) 'TERM=xterm $(DEST)$(TRIAL)'

CLEAN := Remove the outputs of this application from build/
clean:
	rm -rf $(ROOT)/build/out/$(APP)-* $(ROOT)/build/obj/$(APP)-*
