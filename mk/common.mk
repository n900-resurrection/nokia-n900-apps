# Shared part of the Makefiles (root and apps/<app>/Makefile): settings, colours, help.
# Usage: at the top of a Makefile `include <path>/mk/common.mk`, then define TARGETS,
# `.PHONY: $(TARGETS)` and the targets. The default goal is help.
#
# Convention: every target is preceded by a variable named like the target in UPPER CASE whose
# value is the description of the target. The `help` target builds its output from them. To add
# a target: put its name into TARGETS and define the description variable right before it.
# Do not use # or a single quote in descriptions.
# Caution: no target may be called shell (the variable SHELL selects the shell make runs).
# Also avoid target names whose upper-case form clashes with a variable defined here.

# Project root (the directory above mk/)
ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/..)

# Settings: .env.default (versioned defaults), then .env (local, git-ignored, overrides the
# defaults). The command line wins over both: make push DEVICE=user@ip
include $(ROOT)/.env.default
-include $(ROOT)/.env

# Commands inside the Workshop. -p selects the project, so they work from subdirectories too.
WORKSHOP := workshop -p $(ROOT)
# INSIDE goes through scripts/ws-exec.sh: it does not hang when `workshop exec` fails to return after the command ended
INSIDE   := $(ROOT)/scripts/ws-exec.sh $(ROOT) $(WS)
WSRUN    := $(WORKSHOP) run $(WS) --

# Colours: enabled only on a terminal (stderr is a tty). FORCE_COLOR=1 forces, NO_COLOR=1 disables.
COLOR_ON := $(if $(NO_COLOR),,$(if $(FORCE_COLOR),y,$(shell test -t 2 && echo y)))
ifneq ($(COLOR_ON),)
RED    := $(shell printf '\033[0;31m')
GREEN  := $(shell printf '\033[0;32m')
YELLOW := $(shell printf '\033[0;33m')
BLUE   := $(shell printf '\033[0;34m')
PURPLE := $(shell printf '\033[0;35m')
CYAN   := $(shell printf '\033[0;36m')
BOLD   := $(shell printf '\033[1m')
RESET  := $(shell printf '\033[0m')
endif

.DEFAULT_GOAL := help

uc = $(shell echo '$(1)' | tr 'a-z' 'A-Z')

HELP := Show the available targets and their descriptions
help:
	@printf '$(BOLD)Usage:$(RESET) make $(CYAN)<target>$(RESET)\n\n'
	@$(foreach t,$(TARGETS),printf '$(CYAN)%-11s$(RESET) %s\n' '$(t)' '$($(call uc,$(t)))';)
