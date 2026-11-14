# smb: small SMB2/SMB3 client (ls, get, put, rm, mkdir, mv ...) on libsmb2, static. Targets and conventions: ../../mk/app.mk
override APP     := smb
VERSION ?= 0.1
# EPOCH 1: the community package of this name has an epoch (mc 1:4.8.14, git 1:1.8.3, smb 3.5.6 in extras-devel); without it that older package counts as the newer one
EPOCH   ?= 1
REV     ?= 1maemo2
RUN_CMD := /usr/bin/smb
include ../../mk/app.mk
