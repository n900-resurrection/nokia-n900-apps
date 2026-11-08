# apt-mirror: a short guide (2026-11-08)

`apt-mirror` is a small Perl tool of Debian/Ubuntu (`apt install apt-mirror`) that copies an apt repository to local disk: the `dists/` indexes and every
file that they list in `pool/`. The result is a plain directory tree that any web server (or `file://`) can serve, so it is the usual way to make a backup or
a mirror of an apt repository. **Not run in this project yet**: the text below comes from the documentation of the tool and from looking at a mirror that
was made with it (`maemo.plan9.de`, see below); check the details with `man apt-mirror` before relying on them.

## Configuration: `/etc/apt/mirror.list`
```
set base_path    /srv/apt-mirror              # where everything lives (default /var/spool/apt-mirror)
set nthreads     5                            # parallel downloads (be polite to old servers)
set _tilde       0
# one line per repository: type, URL, distribution, components
deb-armel http://repository.maemo.org/extras         fremantle free non-free
deb-armel http://repository.maemo.org/extras-testing fremantle free
clean http://repository.maemo.org/extras             # remove files that are no longer listed
```
- `deb` is the architecture of the machine; `deb-armel` / `deb-i386` select the architecture explicitly (needed for a foreign one such as the armel of the N900);
  `deb-src` also fetches the source packages.
- `skip-clean URL` keeps files that are no longer in the index (useful for an archive: old versions stay).
- Repositories of the Maemo 5 style (`deb URL fremantle free non-free`) use the same format as everything else.

## Running
```
apt-mirror                  # reads /etc/apt/mirror.list, downloads, then runs var/postmirror.sh if present
apt-mirror other.list       # another configuration file
```
It downloads the indexes first, builds the list of the files, fetches only what is new or has a different size, and can be run again (or from cron)
to update the mirror. The first run of a large repository takes long, so run it where the disk and the bandwidth are.

## What it creates under `base_path`
```
mirror/<host>/<path>/dists/...    pool/...      the copy, e.g. mirror/repository.maemo.org/extras/pool/fremantle/free/m/munadi/munadi_0.2.0_armel.deb
skel/                             the downloaded indexes (the working copy)
var/ALL, var/index, var/postmirror.sh, var/clean.sh, var/apt-mirror.log
```
Serve `mirror/<host>/<path>` with any web server and use it on a client like any repository:
```
deb http://my.server/apt-mirror/mirror/repository.maemo.org/extras fremantle free
```
Nothing is signed by apt-mirror: the `Release` / `Release.gpg` files are copied as they are, so a client that trusts the original key accepts the copy.

## The Maemo mirror of plan9 (found 2026-11-08)
`https://maemo.plan9.de/apt-mirror/mirror/repository.maemo.org/` is exactly such a tree, made on **2017-09-20**: `extras`, `extras-testing`, `extras-devel`,
`community-testing` (each with `dists/{fremantle,fremantle-1.2,fremantle-1.3}/{free,non-free}` and a shared `pool/`). The `Packages` files list `Size`, `MD5sum`,
`SHA1`, `SHA256`, `SHA512` of every package, so a copy can be verified. Sizes computed from the indexes (unique files, armel and i386 together):

| repository | files | size |
|---|---:|---:|
| extras | 12 000 | 13.6 GB |
| extras-testing | 5 700 | 7.5 GB |
| extras-devel | 24 600 | 38.2 GB |
| community-testing | 1 600 | 2.3 GB |
| **all** | **43 800** | **61.6 GB** (armel only about 46 GB) |

The armel part of `extras` (free) is about 3.5 GB, of `extras-testing` about 6 GB; `extras-devel` is mostly nightly builds (27 GB armel).

## Why not simply put it on GitHub
GitHub Pages serves at most about 1 GB per site, a repository should stay well under 5 GB (a push is limited, a file to 100 MB), so a full mirror does not fit. Ideas that do:
- a **manifest repository**: the `Packages` indexes (name, version, size, SHA-256, source URL) plus a script that downloads and verifies the files (tiny, forkable);
- the **binaries** elsewhere (Internet Archive, torrent, own storage);
- a small **selected subset** as ordinary apt repositories on GitHub Pages (each under 1 GB), as `n900-repository` already is (see `DOC/apt-repo.md`; `scripts/mkrepo.sh`).
Leave `non-free` out of any public copy (licences of proprietary packages). Decision on 2026-11-08: 61 GB is too much, the mirror is put aside for now (see TODO).

## Alternatives to apt-mirror
- `wget -m` / `rsync` of the tree (when the server offers rsync), then `dpkg-scanpackages` to rebuild the indexes of a selection of packages;
- `debmirror` (similar to apt-mirror, supports GPG verification and `--rsync-extra`);
- our own `scripts/mkrepo.sh` for a repository that holds only the packages built in this project.
