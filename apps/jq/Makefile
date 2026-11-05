# jq 1.8 (JSON processor) for Maemo 5. Targets and conventions: ../../mk/app.mk
APP     := jq
VERSION ?= 1.8.2
RUN_CMD := echo '{"a":[1,2]}' | /usr/bin/jq -c '.a|map(.*2)'
include ../../mk/app.mk
