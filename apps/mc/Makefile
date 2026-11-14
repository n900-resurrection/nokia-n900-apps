# Midnight Commander (mc), two-panel file manager in the terminal (GLib 2.66 and ncursesw linked statically). Targets and conventions: ../../mk/app.mk
override APP     := mc
VERSION ?= 4.8.33
# EPOCH 1: the community package of this name has an epoch (mc 1:4.8.14, git 1:1.8.3, smb 3.5.6 in extras-devel); without it that older package counts as the newer one
EPOCH   ?= 1
REV     ?= 1maemo2
DEPS    := glib2
RUN_CMD := /usr/bin/mc --version | head -1
include ../../mk/app.mk
