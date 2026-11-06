# Package repository (apt) for the N900

`make repo` builds the directory `n900-repository/` from the current `.deb` of every app (it runs `make debs` first, so everything
that is up to date is skipped). The directory is meant to become a separate git repository (a GitHub repository in the
`n900-resurrection` organisation); the main project only produces its content.

```
n900-repository/pool/main/*.deb
n900-repository/dists/fremantle/main/binary-armel/Packages, Packages.gz
n900-repository/dists/fremantle/Release        (MD5Sum, SHA1, SHA256)
```
Script: [scripts/mkrepo.sh](../scripts/mkrepo.sh). The old apt of the phone reads only `Packages.gz` (no xz) and knows only MD5/SHA1,
so `Release` carries all three sums.

## Use on the phone
Put this into `/etc/apt/sources.list.d/n900.list`:
```
deb http://ADDRESS fremantle main
```
then `apt-get update` and `apt-get install quickjs`. The Application Manager lists the packages too. Verified on 2026-11-06 with the
repository served by `python3 -m http.server` from the PC (`apt-get update`, `apt-cache policy`, `apt-get install --force-yes camel-lite-ssl3`).

## Known limits
- **No signature yet** (`Release.gpg` is missing: apt prints `Ign ... Release.gpg` and needs `--force-yes` to install). Plan: [TODO.md](../TODO.md).
- **HTTPS:** the apt of the phone speaks TLS 1.0 only, GitHub (Pages and raw) requires TLS 1.2. Solution: the package `apt-transport-curl`
  ([description](../apps/apt-transport-curl/apt-transport-curl.md)), whose `https` method runs curl 8. Verified against an HTTPS server on the PC
  and against github.com; a real repository on GitHub Pages has not been tried yet. The first installation (bootstrap) is done by hand
  with `dpkg -i` or over HTTP.
- The version of a package follows `VERSION` and `REV` in `apps/<app>/Makefile`; raise `REV` to make an update visible to users.
