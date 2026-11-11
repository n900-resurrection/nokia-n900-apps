# xml-tools: xmllint and xsltproc (libxml2 + libxslt, static) for Maemo 5. Targets and conventions: ../../mk/app.mk
override APP     := xml-tools
VERSION ?= 2.15.4
RUN_CMD := echo '<a><b>1</b></a>' | /usr/bin/xmllint --xpath 'string(//b)' -
include ../../mk/app.mk
