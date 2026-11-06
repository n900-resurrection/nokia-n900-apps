# OpenSSL 3.x as a static build dependency (not a package). Targets: ../../mk/common.mk
include ../../mk/common.mk

VERSION ?= 3.5.9
TARGETS := help build clean
.PHONY: $(TARGETS) stamp

BUILD := Build static OpenSSL $(VERSION) (LTS) into build/deps/ in the workshop
build:
	$(INSIDE) bash -c 'VERSION=$(VERSION) /project/apps/openssl/build.sh'
	@mkdir -p $(ROOT)/build/stamps && touch $(STAMP) $(ROOT)/build/stamps/openssl.built

# Same stamp interface as mk/app.mk (other applications list openssl in DEPS).
STAMP := $(ROOT)/build/stamps/openssl-$(VERSION).built
$(STAMP): $(wildcard $(ROOT)/apps/openssl/*.sh)
	$(MAKE) build
stamp: $(STAMP)

CLEAN := Remove OpenSSL from build/
clean:
	rm -rf $(ROOT)/build/stamps/openssl*.built $(ROOT)/build/deps/openssl-* $(ROOT)/build/obj/openssl-*
