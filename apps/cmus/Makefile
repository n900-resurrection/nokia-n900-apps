# cmus (music player for the terminal) for Maemo 5: PulseAudio output, ffmpeg input plugin (mp3, aac, opus, vorbis, flac, ...). Targets and conventions: ../../mk/app.mk
# Needs the ffmpeg of apps/ffmpeg (make -C apps/ffmpeg build).
override APP     := cmus
VERSION ?= 2.13.0
REV     ?= 1maemo1
RUN_CMD := TERM=xterm /usr/bin/cmus --version | head -1
include ../../mk/app.mk
