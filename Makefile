# Ovládání vývojového prostředí pro Maemo 5 (Workshop "n900").
# Spouští se na hostiteli, příkazy běží v kontejneru. Viz DOC/workshop-crosscompile.md.
#
# Konvence: před každým cílem je proměnná se jménem cíle VELKÝMI PÍSMENY, jejíž
# obsah je popis cíle. Cíl `help` z nich sestaví nápovědu. Nový cíl = přidat jeho
# jméno do TARGETS a před něj proměnnou s popisem. V popisech nepoužívat # ani '.
# Pozor: cíl se nesmí jmenovat shell (proměnná SHELL ovládá, jakým shellem make běží).

# Nastavení: .env.default (ve verzování, výchozí hodnoty), potom .env (lokální, v .gitignore,
# přepisuje výchozí). Nejvyšší prioritu má příkazová řádka: make push DEVICE=user@ip
include .env.default
-include .env

RUN := workshop run $(WS) --

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

TARGETS := help up down status enter toolchain sysroot hello push clean distclean
.PHONY: $(TARGETS)
.DEFAULT_GOAL := help

uc = $(shell echo '$(1)' | tr 'a-z' 'A-Z')

HELP := Vypise dostupne cile a jejich popis
help:
	@printf '$(BOLD)Pouziti:$(RESET) make $(CYAN)<cil>$(RESET)\n\n'
	@$(foreach t,$(TARGETS),printf '$(CYAN)%-11s$(RESET) %s\n' '$(t)' '$($(call uc,$(t)))';)

UP := Vytvori a spusti workshop (prvni spusteni)
up:
	workshop launch $(WS)

DOWN := Zastavi workshop
down:
	workshop stop $(WS)

STATUS := Stav workshopu
status:
	workshop list

ENTER := Interaktivni shell uvnitr workshopu
enter:
	workshop shell $(WS)

TOOLCHAIN := Nainstaluje cross-toolchain (armel) a qemu-user
toolchain:
	$(RUN) toolchain

SYSROOT := Stahne sysroot z Fremantle SDK do ./sysroot
sysroot:
	$(RUN) sysroot

HELLO := Prelozi a spusti hello.c (qemu-user, glibc 2.5)
hello:
	$(RUN) hello

PUSH := Zkopiruje FILE na N900: make push DEVICE=user@ip [FILE=build/hello]
push:
	@test -n "$(DEVICE)" || { printf '$(RED)Zadej DEVICE=user@ip (do .env nebo na prikazovou radku)$(RESET)\n'; exit 1; }
	scp $(FILE) $(DEVICE):$(DEST)

CLEAN := Smaze ./build
clean:
	rm -rf build

DISTCLEAN := Smaze i ./sysroot a ./downloads
distclean: clean
	rm -rf sysroot downloads
