# GLib 2.66 as a static build dependency (not a package). Targets: ../../mk/common.mk
include ../../mk/common.mk

VERSION ?= 2.66.8
TARGETS := help build clean
.PHONY: $(TARGETS) stamp

BUILD := Build static GLib $(VERSION) into build/deps/ in the workshop
build:
	$(INSIDE) bash -c 'VERSION=$(VERSION) /project/apps/glib2/build.sh'
	@mkdir -p $(ROOT)/build/stamps && touch $(STAMP) $(ROOT)/build/stamps/glib2.built

# Same stamp interface as mk/app.mk (other applications list glib2 in DEPS).
STAMP := $(ROOT)/build/stamps/glib2-$(VERSION).built
$(STAMP): $(wildcard $(ROOT)/apps/glib2/*.sh)
	$(MAKE) build
stamp: $(STAMP)

CLEAN := Remove GLib from build/
clean:
	rm -rf $(ROOT)/build/stamps/glib2*.built $(ROOT)/build/deps/glib2-* $(ROOT)/build/obj/glib2-*
