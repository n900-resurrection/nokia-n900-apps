# apt-transport-curl: apt method "https" over curl 8 (TLS 1.2/1.3). Targets and conventions: ../../mk/app.mk
override APP     := apt-transport-curl
VERSION ?= 0.1
RUN_CMD := apt-get -o Dir::Etc::sourcelist=/dev/null -o Dir::Etc::sourceparts=/nonexistent update
include ../../mk/app.mk
