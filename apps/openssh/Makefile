# OpenSSH (ssh, scp, sftp, sshd...) with a private static OpenSSL 3 for Maemo 5, installed in /opt/openssh. The default revision (1maemo6 and above) REPLACES the system
# OpenSSH 5.1 (openssh-client, -server, -common); the parallel kind (1maemo5, next to it, for the trial with openssh-switch) is made with: make deb REV=1maemo5. See README.md.
# Targets and conventions: ../../mk/app.mk. Tested on the test phone (2026-11-27), including a restart.
override APP     := openssh
VERSION ?= 10.6p2
# EPOCH 1: Extras has this name with the epoch 1 (1:5.1p1); without it that older package would count as the newer one
EPOCH   ?= 1
REV     ?= 1maemo7
DEPS    := openssl
RUN_CMD := /opt/openssh/bin/ssh -V
include ../../mk/app.mk

# Emulation test (sshd, ssh, sftp over loopback under qemu-user); the phone is not used.
QEMU-TEST := Test sshd, ssh and sftp over loopback under qemu-user (not on the phone)
.PHONY: qemu-test
qemu-test:
	$(INSIDE) /project/apps/openssh/qemu-test.sh

# the switch script is in a subdirectory, which the stamps of app.mk do not look at: the package has to be made again when it changes
$(ROOT)/build/stamps/openssh-$(VERSION)-$(REV).packaged: $(wildcard $(ROOT)/apps/openssh/switch/*)
