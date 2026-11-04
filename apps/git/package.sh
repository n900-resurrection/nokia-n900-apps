#!/bin/bash
# Package the built git as a .deb ("git") for Maemo 5. Run INSIDE the Workshop after build.sh:
#   workshop exec n900 -- bash -c 'GIT_VERSION=2.56.0 REV=1maemo1 /project/apps/git/package.sh'
#   (or on the host: make -C apps/git deb)
# Output: /project/build/deb/git_<GIT_VERSION>-<REV>_armel.deb
#
# The package is called "git" on purpose: it upgrades the old git 1.6.2-1 of the device (which is
# installed from a plain .deb in /usr, about 10 MB on the small root partition) and moves git to /opt.
# To go back: install the old git_1.6.2-1_armel.deb again.
#
# Status: the package builds and can be inspected. Installation on a device is not verified yet.
# The build tree itself was verified on a real N900 (version, ls-remote and clone over HTTPS).
set -euo pipefail

APP=git
GIT_VERSION="${GIT_VERSION:-2.56.0}"
CURL_VERSION="${CURL_VERSION:-8.23.0}"
REV="${REV:-1maemo1}"
MAINT="${MAINTAINER:-elPytel}"
PROJ=/project
OUT="$PROJ/build/out/git-$GIT_VERSION"
SRC="$PROJ/build/src/git-$GIT_VERSION"
TREE="$OUT/root/opt/git"
STAGE="$PROJ/build/deb/stage-$APP"
DEB="$PROJ/build/deb/${APP}_${GIT_VERSION}-${REV}_armel.deb"

[ -x "$TREE/bin/git" ] || { echo "Missing build output in $OUT, run build.sh first (make build)"; exit 1; }

rm -rf "$STAGE"
mkdir -p "$STAGE/DEBIAN" "$STAGE/opt" "$STAGE/usr/bin"

# Copy the installed tree as it is (-a keeps the symlinks in libexec/git-core).
cp -a "$TREE" "$STAGE/opt/git"

# Link in PATH. git resolves its helper programs relative to the real binary (RUNTIME_PREFIX), and
# does so after following this symlink, so it finds /opt/git/libexec/git-core.
ln -s ../../opt/git/bin/git "$STAGE/usr/bin/git"

mkdir -p "$STAGE/opt/git/share/doc/git"
install -m 644 "$SRC/COPYING" "$STAGE/opt/git/share/doc/git/COPYING"
cat > "$STAGE/opt/git/share/doc/git/README.Maemo" <<EOF
git $GIT_VERSION built for Maemo 5 (armel, glibc 2.5). Upstream: https://git-scm.com/
Built from the unmodified release tarball. Differences from a normal build: no Perl, Python,
Tcl/Tk, gettext, expat (no WebDAV push) and no fsmonitor daemon, because those need libraries
or system calls that this old system does not have. See the build script apps/git/build.sh.

HTTPS: git-remote-http is linked statically with libcurl $CURL_VERSION, mbedTLS (TLS 1.2/1.3) and zlib.
CA bundle: the one of the "curl" package, /opt/curl/etc/ssl/cacert.pem. To use another bundle:
  git config --global http.sslCAInfo /path/to/cacert.pem

Installed in /opt/git (relocatable, RUNTIME_PREFIX), with a link /usr/bin/git. Helper programs in
/opt/git/libexec/git-core are symlinks to the single "git" binary.
Commands implemented as shell scripts (git-pull, git-rebase, git-submodule, ...) need a POSIX shell,
they use /bin/sh (busybox ash). If one of them misbehaves, please report it.
EOF

SIZE_KB=$(du -sk "$STAGE" | cut -f1)
cat > "$STAGE/DEBIAN/control" <<EOF
Package: $APP
Version: $GIT_VERSION-$REV
Architecture: armel
Section: user/development
Priority: optional
Installed-Size: $SIZE_KB
Depends: libc6 (>= 2.5.1-1eglibc27), curl (>= $CURL_VERSION)
Maintainer: $MAINT
XB-Maemo-Display-Name: git
Description: Distributed version control system (modern, HTTPS over TLS 1.3)
 git $GIT_VERSION built for Maemo 5, linked with libcurl and mbedTLS so that it can clone from
 HTTPS servers such as GitHub (the old git 1.6.2 of the device cannot). Installed in /opt/git,
 replaces the git 1.6.2-1 package. Upstream: https://git-scm.com/
EOF

# Uniform permissions (the container umask gives group-write): directories 755, files 644,
# executables stay 755.
chmod -R u+rwX,go+rX,go-w "$STAGE"

mkdir -p "$(dirname "$DEB")"
# gzip: the old dpkg on Maemo 5 (1.14) does not know xz. --root-owner-group: files belong to root:root.
dpkg-deb --root-owner-group -Zgzip --build "$STAGE" "$DEB"

echo "== Package"
dpkg-deb -I "$DEB"
echo "files: $(dpkg-deb -c "$DEB" | wc -l), symlinks: $(dpkg-deb -c "$DEB" | grep -c '^l')"
ls -l "$DEB"
