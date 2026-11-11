# xml-tools 2.15.4 for Maemo 5

`xmllint` and `xsltproc` (libxml2 2.15.4 + libxslt 1.1.45 with EXSLT), statically linked. The phone has only the library `libxml2 2.6.32`, no command-line tools.

```sh
make -C apps/xml-tools install     # build (when out of date), deb, scp, dpkg -i
make -C apps/xml-tools test        # 10 tests on the phone
echo '<a><b>1</b></a>' | xmllint --xpath 'string(//b)' -
xmllint --format file.xml
xsltproc style.xsl file.xml
```

- Installs to `/opt/xml-tools`, links in `/usr/bin`. The system libxml2 is not touched.
- Built without Python, ICU, LZMA, zlib and readline (smaller, no extra dependencies): no compressed input, no `xmllint --shell` history. Character sets other than UTF-8 and ASCII need the glibc `gconv` modules on the phone.
- libxslt 1.1.45 needs libxml2 >= 2.15.1, so libxml2 2.14 does not work.
- `xmlstarlet` (shell-friendly XML editing) is not included: release 1.6.1 (2014) does not compile against libxml2 2.15 (`ATTRIBUTE_UNUSED` is gone, error callbacks take `const xmlError *`). It would need a small patch; the XPath use is covered by `xmllint --xpath`.
