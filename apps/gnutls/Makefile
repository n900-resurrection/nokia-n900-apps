# GnuTLS 3.8 as a static build dependency (not a package). Targets: ../../mk/common.mk
include ../../mk/common.mk

VERSION ?= 3.8.13
TARGETS := help build clean
.PHONY: $(TARGETS) stamp

BUILD := Build static GnuTLS $(VERSION) into build/deps/ in the workshop
build:
	$(INSIDE) bash -c 'VERSION=$(VERSION) /project/apps/gnutls/build.sh'
	@mkdir -p $(ROOT)/build/stamps && touch $(STAMP) $(ROOT)/build/stamps/gnutls.built

# Same stamp interface as mk/app.mk (other applications list gnutls in DEPS).
STAMP := $(ROOT)/build/stamps/gnutls-$(VERSION).built
$(STAMP): $(wildcard $(ROOT)/apps/gnutls/*.sh)
	$(MAKE) build
stamp: $(STAMP)

CLEAN := Remove GnuTLS from build/
clean:
	rm -rf $(ROOT)/build/stamps/gnutls*.built $(ROOT)/build/deps/gnutls-* $(ROOT)/build/obj/gnutls-*
