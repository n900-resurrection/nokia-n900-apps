# OpenSSH (ssh, scp, sftp, sshd...) with a private static OpenSSL 3 for Maemo 5, installed in /opt/openssh next to the system one.
# Targets and conventions: ../../mk/app.mk. NOT tested on the phone by agreement (a broken sshd would lock out the remote access).
override APP     := openssh
VERSION ?= 10.6p2
REV     ?= 1maemo1
DEPS    := openssl
RUN_CMD := /opt/openssh/bin/ssh -V
include ../../mk/app.mk

# Emulation test (sshd, ssh, sftp over loopback under qemu-user); the phone is not used.
QEMU-TEST := Test sshd, ssh and sftp over loopback under qemu-user (not on the phone)
.PHONY: qemu-test
qemu-test:
	$(INSIDE) /project/apps/openssh/qemu-test.sh
