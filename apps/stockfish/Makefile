# Stockfish 11 (UCI chess engine, classical evaluation, no NNUE network) for Maemo 5: static musl binary. Targets and conventions: ../../mk/app.mk
# Needs the musl cross g++ that apps/gurk/build.sh fetches.
override APP     := stockfish
VERSION ?= 11
REV     ?= 1maemo1
RUN_CMD := /usr/bin/stockfish bench 16 1 8 | tail -4
include ../../mk/app.mk
