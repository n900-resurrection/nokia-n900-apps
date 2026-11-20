# GNU less for Maemo 5: the phone has only the pager of BusyBox, which has no --version, marks or the options that offpunk needs.
# Installed in /opt/less (not over the pager of the system). Targets and conventions: ../../mk/app.mk
override APP     := less
VERSION ?= 710
REV     ?= 1maemo1
RUN_CMD := TERM=xterm /opt/less/bin/less --version | head -2
include ../../mk/app.mk
