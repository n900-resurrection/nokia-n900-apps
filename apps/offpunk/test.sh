TEST_NAME=offpunk
need_pkg offpunk
ok in-path sh -c 'command -v offpunk && command -v ansicat && command -v netcache && command -v openk'
ok version sh -c 'offpunk --version | grep -q "^Offpunk 3.1"'
ok runs-as-user sh -c 'su user -c "offpunk --version" | grep -q "^Offpunk 3.1"'
ok desktop-entry test -r /usr/share/applications/hildon/offpunk.desktop
ok license test -r /opt/offpunk/share/doc/offpunk/LICENSE-offpunk-3.1
D=/home/user/offpunk-test; rm -rf $D; mkdir -p $D
printf '# Heading\n\nA line of text.\n=> gemini://example.org/ a link\n* item\n' > $D/t.gmi
ok ansicat-gemtext-stdin sh -c "su user -c 'ansicat --format gemtext < $D/t.gmi' | grep -q 'A line of text'"
ok ansicat-link-number sh -c "su user -c 'ansicat --format gemtext < $D/t.gmi' | grep -q 'a link'"
printf '<html><body><h1>Title</h1><p>Some <b>paragraph</b>.</p></body></html>' > $D/t.html
ok ansicat-html sh -c "su user -c 'ansicat --format html < $D/t.html' | grep -q 'paragraph'"
ok https-libs sh -c "su user -c 'PYTHONPATH=/opt/offpunk/lib /opt/python3/bin/python3.11 -c \"import requests, bs4, feedparser; print(requests.get)\"' >/dev/null"
rm -rf $D
summary
