TEST_NAME=apt-transport-curl
need_pkg apt-transport-curl
M=/usr/lib/apt/methods
# a request to the method as apt sends it: $1 = URI
acq() { printf '600 URI Acquire\nURI: %s\nFilename: /tmp/atc-test.out\n\n' "$1" | $M/https; }
ok method-installed test -x $M/https
ok original-kept test -x $M/https.distrib
contains diversion "apt-transport-curl" dpkg-divert --list
contains capabilities "100 Capabilities" sh -c ": | $M/https"
contains pipeline "Pipeline: true" sh -c ": | $M/https"
contains https-tls13 "201 URI Done" acq https://github.com/robots.txt
t size-reported 14 sh -c 'acq() { printf "600 URI Acquire\nURI: %s\nFilename: /tmp/atc-test.out\n\n" "$1" | /usr/lib/apt/methods/https; }; acq https://github.com/robots.txt | grep -c "^\(Size\|MD5-Hash\|SHA1-Hash\|SHA256-Hash\): " | sed "s/^4$/14/"'
contains http-404 "400 URI Failure" acq https://github.com/nonexistent-page-for-test-404
contains http-404-message "HTTP 404" acq https://github.com/nonexistent-page-for-test-404
contains cert-verified "certificate" acq https://self-signed.badssl.com/
ok file-removed-on-failure sh -c 'rm -f /tmp/atc-test.out; printf "600 URI Acquire\nURI: https://github.com/nonexistent-page-for-test-404\nFilename: /tmp/atc-test.out\n\n" | /usr/lib/apt/methods/https >/dev/null; test ! -e /tmp/atc-test.out'
rm -f /tmp/atc-test.out
summary
