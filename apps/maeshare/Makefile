# MaeShare (LocalSend client for the N900), built from our fork https://github.com/n900-resurrection/MaeShare (Czech translation, fix for non-English
# locales) with the Qt 4.7 of the SDK sysroot and moc of apps/qt-moc. Targets and conventions: ../../mk/app.mk
#   make maeshare ACTION=deb      build the program and the package (build/deb/maeshare_1.0.3-1maemo1_armel.deb)
#   make -C apps/maeshare install / test
override APP := maeshare
VERSION ?= 1.0.3
REV     ?= 1maemo1
DEPS    := qt-moc
# Not in `make debs` / `make repo` yet: the package of the author (scripts/external.conf, 1.0.3) has the same name; decide which one the repository ships.
MANUAL := yes
include ../../mk/app.mk
