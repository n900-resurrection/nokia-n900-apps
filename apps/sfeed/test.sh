TEST_NAME=sfeed
need_pkg sfeed
ok tools-in-path sh -c 'command -v sfeed && command -v sfeed_plain && command -v sfeed_curses && command -v sfeed_update'
ok no-missing-libs sh -c '! ldd /opt/sfeed/bin/sfeed_curses 2>&1 | grep -q "not found"'
# Parse a small RSS document: the sfeed format is tab separated (timestamp, title, link, content, type, id, author, enclosure, category).
cat > /tmp/sfeed-test.xml <<'XML'
<?xml version="1.0"?><rss version="2.0"><channel><title>T</title>
<item><title>Prvni epizoda</title><link>http://example.com/1</link><guid>g1</guid>
<pubDate>Tue, 03 Nov 2026 10:00:00 +0000</pubDate>
<enclosure url="http://example.com/1.mp3" type="audio/mpeg" length="1"/></item>
</channel></rss>
XML
t parse-title 'Prvni epizoda' sh -c 'sfeed < /tmp/sfeed-test.xml | cut -f2'
t parse-link 'http://example.com/1' sh -c 'sfeed < /tmp/sfeed-test.xml | cut -f3'
t parse-enclosure 'http://example.com/1.mp3' sh -c 'sfeed < /tmp/sfeed-test.xml | cut -f8'
t parse-timestamp 1793700000 sh -c 'sfeed < /tmp/sfeed-test.xml | cut -f1'
contains plain-output "Prvni epizoda" sh -c 'sfeed < /tmp/sfeed-test.xml | sfeed_plain'
ok example-config test -r /opt/sfeed/share/doc/sfeed/sfeedrc.example
ok desktop-entry test -r /usr/share/applications/hildon/sfeed.desktop
# Real download through curl (TLS 1.3) and parse: needs the network.
# sfeed_update with a local "feed" (the busybox xargs of the phone has no -P: the update must still work)
cat > /tmp/sfeed-test.rc <<'EOT'
sfeedpath="/tmp/sfeed-test-feeds"
fetch() { cat /tmp/sfeed-test.xml; }
feeds() { feed "test" "http://example.com/feed.xml"; }
EOT
rm -rf /tmp/sfeed-test-feeds; mkdir -p /tmp/sfeed-test-feeds
ok update-downloads-feed sh -c 'sfeed_update /tmp/sfeed-test.rc >/dev/null 2>&1; grep -q "Prvni epizoda" /tmp/sfeed-test-feeds/test'
rm -rf /tmp/sfeed-test.rc /tmp/sfeed-test-feeds

# no feed downloaded: the reader explains it and waits for Enter (stdin is closed here) instead of closing the terminal window
ok reader-explains-no-feeds sh -c 'rm -rf /tmp/sfeed-home; mkdir -p /tmp/sfeed-home/.sfeed; echo "sfeedpath=/tmp/sfeed-home/.sfeed/feeds; fetch() { :; }; feeds() { :; }" > /tmp/sfeed-home/.sfeed/sfeedrc; HOME=/tmp/sfeed-home sfeed-reader -n </dev/null 2>&1 | grep -q "Press Enter"; rm -rf /tmp/sfeed-home'

ok fetch-and-parse sh -c 'curl -sf -m 60 --cacert /opt/curl/etc/ssl/cacert.pem https://codemadness.org/atom.xml | sfeed | grep -q .'
rm -f /tmp/sfeed-test.xml
summary
