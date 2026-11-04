# Společná část Makefile (kořenový i apps/<app>/Makefile): nastavení, barvy, help.
# Použití: na začátku Makefile `include <cesta>/mk/common.mk`, potom definovat TARGETS,
# `.PHONY: $(TARGETS)` a cíle. Výchozí cíl je help.
#
# Konvence: před každým cílem je proměnná se jménem cíle VELKÝMI PÍSMENY, jejíž
# obsah je popis cíle. Cíl `help` z nich sestaví nápovědu. Nový cíl = přidat jeho
# jméno do TARGETS a před něj proměnnou s popisem. V popisech nepoužívat # ani '.
# Pozor: cíl se nesmí jmenovat shell (proměnná SHELL ovládá, jakým shellem make běží).

# Kořen projektu (složka nad mk/)
ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/..)

# Nastavení: .env.default (ve verzování, výchozí hodnoty), potom .env (lokální, v .gitignore,
# přepisuje výchozí). Nejvyšší prioritu má příkazová řádka: make push DEVICE=user@ip
include $(ROOT)/.env.default
-include $(ROOT)/.env

# Příkazy uvnitř Workshopu. -p určuje projekt, takže fungují i z podsložek.
WORKSHOP := workshop -p $(ROOT)
INSIDE   := $(WORKSHOP) exec $(WS) --
WSRUN    := $(WORKSHOP) run $(WS) --

# Barvy: zapnuté jen v terminálu (stderr je tty). FORCE_COLOR=1 vynutí, NO_COLOR=1 vypne.
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

HELP := Vypise dostupne cile a jejich popis
help:
	@printf '$(BOLD)Pouziti:$(RESET) make $(CYAN)<cil>$(RESET)\n\n'
	@$(foreach t,$(TARGETS),printf '$(CYAN)%-11s$(RESET) %s\n' '$(t)' '$($(call uc,$(t)))';)
