# Rust on Maemo 5: cross-compile Rust programs in the Workshop (no Rust on the phone). Targets: ../../mk/common.mk
# "make build" installs the Rust toolchain into build/rust/ and builds src/rust/hello as a static musl binary.
include ../../mk/common.mk

TARGETS := help build push run clean
.PHONY: $(TARGETS)

BUILD := Install Rust into build/rust/ and cross-compile src/rust/hello for the N900 (armv7 musl, static)
build:
	$(INSIDE) /project/apps/rust/build.sh

PUSH := Copy build/rust/hello-rust to the N900 into DEST
push:
	@test -n "$(DEVICE)" || { printf '$(RED)Set DEVICE$(RESET)\n'; exit 1; }
	ssh $(DEVICE) mkdir -p $(DEST)
	scp $(ROOT)/build/rust/hello-rust $(DEVICE):$(DEST)

RUN := Run the Rust test program on the N900 over ssh
run:
	ssh -t $(DEVICE) '$(DEST)hello-rust'

CLEAN := Remove the toolchain and Rust outputs from build/rust/
clean:
	rm -rf $(ROOT)/build/rust
