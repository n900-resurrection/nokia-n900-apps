TEST_NAME=xml-tools
need_pkg xml-tools
contains version "libxml version 215" xmllint --version
t xpath 2 sh -c 'echo "<a><b>1</b><b>2</b></a>" | xmllint --xpath "string(//b[2])" -'
t xpath-count 3 sh -c 'echo "<a><b/><b/><b/></a>" | xmllint --xpath "count(//b)" -'
t format '  <b>1</b>' sh -c 'echo "<a><b>1</b></a>" | xmllint --format - | sed -n 3p'
t wellformed-ok 0 sh -c 'echo "<a/>" | xmllint --noout - ; echo $?'
t wellformed-fails 4 sh -c 'echo "<a>" | xmllint --noout - >/dev/null 2>&1; echo $?'
t unicode 'č' sh -c 'echo "<a>č</a>" | xmllint --xpath "string(/a)" -'
t xslt '<x>1</x>' sh -c '
cat > /tmp/xt.xsl <<XSL
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"><xsl:output method="text"/><xsl:template match="/"><xsl:text>&lt;x&gt;</xsl:text><xsl:value-of select="/a/b"/><xsl:text>&lt;/x&gt;</xsl:text></xsl:template></xsl:stylesheet>
XSL
echo "<a><b>1</b></a>" > /tmp/xt.xml; xsltproc /tmp/xt.xsl /tmp/xt.xml; rm -f /tmp/xt.xsl /tmp/xt.xml'
t exslt 'ABC' sh -c '
cat > /tmp/xe.xsl <<XSL
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:str="http://exslt.org/strings"><xsl:output method="text"/><xsl:template match="/"><xsl:value-of select="str:concat(/a/*)"/></xsl:template></xsl:stylesheet>
XSL
echo "<a><b>A</b><b>B</b><b>C</b></a>" > /tmp/xe.xml; xsltproc /tmp/xe.xsl /tmp/xe.xml; rm -f /tmp/xe.xsl /tmp/xe.xml'
summary
