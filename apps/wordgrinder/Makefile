# WordGrinder pro Maemo 5: sestavení, balení a instalace na N900.
# Spouští se na hostiteli (`make -C apps/wordgrinder <cil>` nebo `cd apps/wordgrinder && make`),
# sestavení a balení běží ve Workshopu. Společná část je v ../../mk/common.mk.

include ../../mk/common.mk

APP     := wordgrinder
VERSION ?= 0.8
REV     ?= 1maemo1
DEBFILE := $(APP)_$(VERSION)-$(REV)_armel.deb

TARGETS := help build deb info push install remove run clean
.PHONY: $(TARGETS)

BUILD := Sestavi binarku ve Workshopu (VERSION=0.8) do build/out/
build:
	$(INSIDE) bash -c 'VERSION=$(VERSION) /project/apps/$(APP)/build.sh'

DEB := Vytvori .deb (armel) v build/deb/ (vyzaduje make build)
deb:
	$(INSIDE) bash -c 'VERSION=$(VERSION) REV=$(REV) /project/apps/$(APP)/package.sh'

INFO := Vypise obsah a metadata balicku
info:
	@test -f $(ROOT)/build/deb/$(DEBFILE) || { printf '$(RED)Chybi build/deb/$(DEBFILE), spust make deb$(RESET)\n'; exit 1; }
	dpkg-deb -I $(ROOT)/build/deb/$(DEBFILE)
	dpkg-deb -c $(ROOT)/build/deb/$(DEBFILE)

PUSH := Zkopiruje .deb na N900 do DEST (vytvori slozku)
push:
	@test -n "$(DEVICE)" || { printf '$(RED)Zadej DEVICE (do .env nebo na prikazovou radku)$(RESET)\n'; exit 1; }
	@test -f $(ROOT)/build/deb/$(DEBFILE) || { printf '$(RED)Chybi build/deb/$(DEBFILE), spust make deb$(RESET)\n'; exit 1; }
	ssh $(DEVICE) mkdir -p $(DEST)
	scp $(ROOT)/build/deb/$(DEBFILE) $(DEVICE):$(DEST)

INSTALL := Nainstaluje .deb na N900 (dpkg -i, meni telefon)
install: push
	ssh $(DEVICE) dpkg -i $(DEST)$(DEBFILE)

REMOVE := Odinstaluje balicek z N900 (dpkg -r)
remove:
	@test -n "$(DEVICE)" || { printf '$(RED)Zadej DEVICE$(RESET)\n'; exit 1; }
	ssh $(DEVICE) dpkg -r $(APP)

RUN := Spusti WordGrinder na N900 pres ssh (TERM=xterm)
run:
	ssh -t $(DEVICE) 'TERM=xterm /usr/bin/$(APP)'

CLEAN := Smaze vystupy teto aplikace z build/
clean:
	rm -rf $(ROOT)/build/out/$(APP)-* $(ROOT)/build/obj/$(APP)-* $(ROOT)/build/deb
