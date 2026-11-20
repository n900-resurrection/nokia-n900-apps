# lf (terminal file manager): Go, static binary (patched Go toolchain of apps/go). Targets and conventions: ../../mk/app.mk
# The upstream tag is r$(VERSION) (lf releases are numbered r1, r2, ...). r41 is the last one that builds with Go 1.24 (r42 needs Go 1.25, which the patched toolchain of apps/go is not yet).
override APP     := lf
VERSION ?= 41
REV     ?= 1maemo1
RUN_CMD := TERM=xterm /usr/bin/lf -version
include ../../mk/app.mk
