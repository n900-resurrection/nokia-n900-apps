# Ovládání vývojového prostředí pro Maemo 5 (Workshop "n900").
# Spouští se na hostiteli, příkazy běží v kontejneru. Viz DOC/workshop-crosscompile.md.
# Společná část (nastavení z .env, barvy, help) je v mk/common.mk, tam je i popis konvence.
# Každá aplikace má svůj Makefile v apps/<app>/ (build, deb, push, install…).

include mk/common.mk

TARGETS := help up down status enter toolchain sysroot hello wordgrinder push clean distclean
.PHONY: $(TARGETS)

UP := Vytvori a spusti workshop (prvni spusteni)
up:
	$(WORKSHOP) launch $(WS)

DOWN := Zastavi workshop
down:
	$(WORKSHOP) stop $(WS)

STATUS := Stav workshopu
status:
	$(WORKSHOP) list

ENTER := Interaktivni shell uvnitr workshopu
enter:
	$(WORKSHOP) shell $(WS)

TOOLCHAIN := Nainstaluje cross-toolchain (armel) a qemu-user
toolchain:
	$(WSRUN) toolchain

SYSROOT := Stahne sysroot z Fremantle SDK do ./sysroot
sysroot:
	$(WSRUN) sysroot

HELLO := Prelozi a spusti hello.c (qemu-user, glibc 2.5)
hello:
	$(WSRUN) hello

WORDGRINDER := Sestavi WordGrinder (dal: make -C apps/wordgrinder)
wordgrinder:
	$(MAKE) -C apps/wordgrinder build

PUSH := Zkopiruje FILE na N900 (vytvori cilovou slozku): make push [DEVICE=n900] [FILE=build/hello]
push:
	@test -n "$(DEVICE)" || { printf '$(RED)Zadej DEVICE=user@ip (do .env nebo na prikazovou radku)$(RESET)\n'; exit 1; }
	ssh $(DEVICE) mkdir -p $(DEST)
	scp $(FILE) $(DEVICE):$(DEST)

CLEAN := Smaze ./build
clean:
	rm -rf build

DISTCLEAN := Smaze i ./sysroot a ./downloads
distclean: clean
	rm -rf sysroot downloads
