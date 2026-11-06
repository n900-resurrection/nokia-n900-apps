# apt-transport-curl: apt over modern HTTPS

The apt of Maemo 5 (0.7.20) fetches `https://` URLs with its own method `/usr/lib/apt/methods/https`, which uses the old libcurl with
OpenSSL 0.9.8. That is TLS 1.0 only, and GitHub, GitHub Pages and most other servers now refuse it
(`SSL23_GET_SERVER_HELLO:tlsv1 alert protocol version`). The package replaces the method with a short bash script (file `https`) that
runs `/usr/bin/curl` 8.x (mbedTLS, TLS 1.2/1.3). apt, Application Manager and `apt-get` need no other change.

## Install
From the repository ([apt-repo.md](../../DOC/apt-repo.md)) over plain HTTP, or by hand: `dpkg -i apt-transport-curl_0.1-1maemo1_armel.deb`
(needs `curl` and the system package `apt-transport-https`). Then a source line such as
```
deb https://USER.github.io/n900-repository fremantle main
```
works. `dpkg-divert` moves the original method to `https.distrib` and `dpkg -r` puts it back (tested).

## How it works
apt starts the method and talks to it on stdin/stdout: `100 Capabilities`, `601 Configuration` (apt settings), `600 URI Acquire`
(URL and target file) answered with `200 URI Start` and `201 URI Done` (size, Last-Modified, MD5/SHA1/SHA256) or `400 URI Failure`.
The script downloads with curl to the file apt names. Requests are handled one after another (`Pipeline: true` is announced because apt
sends several at once).

Two quirks of this old apt, found on the phone:
- if the method answers at once, apt never reads the first message and hangs; the script waits 0.2 s before `100 Capabilities`
  (the compiled methods are slower to start),
- a message must arrive in a single write (the script builds it first).

## Settings (apt.conf)
| Setting | Meaning |
|---|---|
| `Acquire::https::CaInfo` | CA bundle file (default: the one of the curl package) |
| `Acquire::https::Proxy` | proxy URL |
| `Acquire::https::Timeout` | connect and stall timeout in seconds (60) |
| `Acquire::https::Curl-Insecure "true"` | no certificate check |

`Acquire::https::Verify-Peer` is **ignored** on purpose: the phone ships `Verify-Peer "false"` in `/etc/apt/apt.conf.d`, which would
silently disable the check. Certificates are always verified unless `Curl-Insecure` is set.
`APT_CURL_DEBUG=/tmp/log apt-get update` writes the whole conversation with apt into a file.

## Not done
No `If-Modified-Since` (indexes are downloaded again on each `apt-get update`; they are small), no resuming of partial downloads, no
HTTP authentication. Tested with a self-signed server on the PC (CaInfo, missing CA, Curl-Insecure), github.com (TLS 1.3), install of a
package, removal.
