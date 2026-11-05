# OpenSSL 3.x as a static build dependency (not a package). Targets: ../../mk/common.mk
include ../../mk/common.mk

VERSION ?= 3.5.9
TARGETS := help build clean
.PHONY: $(TARGETS)

BUILD := Build static OpenSSL $(VERSION) (LTS) into build/deps/ in the workshop
build:
	$(INSIDE) bash -c 'VERSION=$(VERSION) /project/apps/openssl/build.sh'

CLEAN := Remove OpenSSL from build/
clean:
	rm -rf $(ROOT)/build/deps/openssl-* $(ROOT)/build/obj/openssl-*
