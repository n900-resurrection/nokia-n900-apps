# Go on Maemo 5: cross-compile Go programs on the host (no Go on the phone). Targets: ../../mk/common.mk
# "make build" downloads the Go toolchain into build/go/ and builds src/go/hello.
include ../../mk/common.mk

GO_VERSION ?= 1.24.13
TARGETS := help build push run clean
.PHONY: $(TARGETS)

BUILD := Download Go into build/go/ and cross-compile src/go/hello for the N900 (linux/arm, static)
build:
	GO_VERSION=$(GO_VERSION) $(ROOT)/apps/go/build.sh

PUSH := Copy build/go/hello-go to the N900 into DEST
push:
	@test -n "$(DEVICE)" || { printf '$(RED)Set DEVICE$(RESET)\n'; exit 1; }
	ssh $(DEVICE) mkdir -p $(DEST)
	scp $(ROOT)/build/go/hello-go $(DEVICE):$(DEST)

RUN := Run the Go test program on the N900 over ssh
run:
	ssh -t $(DEVICE) '$(DEST)hello-go'

CLEAN := Remove the downloaded toolchain and Go outputs from build/go/
clean:
	rm -rf $(ROOT)/build/go
