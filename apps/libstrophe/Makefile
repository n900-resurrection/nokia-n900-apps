# libstrophe 0.14 as a static build dependency (not a package). Targets: ../../mk/common.mk
include ../../mk/common.mk

VERSION ?= 0.14.0
TARGETS := help build clean
.PHONY: $(TARGETS) stamp

BUILD := Build static libstrophe $(VERSION) into build/deps/ in the workshop
build:
	$(INSIDE) bash -c 'VERSION=$(VERSION) /project/apps/libstrophe/build.sh'
	@mkdir -p $(ROOT)/build/stamps && touch $(STAMP) $(ROOT)/build/stamps/libstrophe.built

# Same stamp interface as mk/app.mk (other applications list libstrophe in DEPS).
STAMP := $(ROOT)/build/stamps/libstrophe-$(VERSION).built
$(STAMP): $(wildcard $(ROOT)/apps/libstrophe/*.sh)
	$(MAKE) build
stamp: $(STAMP)

CLEAN := Remove libstrophe from build/
clean:
	rm -rf $(ROOT)/build/stamps/libstrophe*.built $(ROOT)/build/deps/libstrophe-* $(ROOT)/build/obj/libstrophe-*
