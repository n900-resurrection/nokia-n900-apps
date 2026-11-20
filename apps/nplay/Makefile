# nplay: our own video player for the N900 (ffmpeg libav* decodes, SDL 1.2 shows and plays). Targets and conventions: ../../mk/app.mk
override APP     := nplay
VERSION ?= 0.1
RUN_CMD := /usr/bin/nplay 2>&1 | head -1
REV     ?= 1maemo3
DEPS    := ffmpeg
include ../../mk/app.mk
