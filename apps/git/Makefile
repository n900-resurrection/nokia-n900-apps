# Modern git (HTTPS over TLS 1.2/1.3) for Maemo 5. Targets and conventions: ../../mk/app.mk
# The package "git" replaces the old git 1.6.2-1 of the device and depends on the "curl" package
# (CA bundle). "make build" needs the curl build first (make -C ../curl build).
# "make emu" only runs git itself: under qemu /proc/self/exe is the emulator, so the RUNTIME_PREFIX
# lookup of the helper programs (git-core) does not work there.
APP     := git
VERSION ?= 2.56.0
RUN_CMD := /usr/bin/git --version && /usr/bin/git ls-remote https://github.com/octocat/Hello-World.git HEAD
EMU_BIN := /project/build/out/git-$(VERSION)/root/opt/git/bin/git
include ../../mk/app.mk
