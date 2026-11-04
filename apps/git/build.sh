#!/bin/bash
# Cross-build a modern git (HTTPS over TLS 1.2/1.3) for Maemo 5 (armel, glibc 2.5).
# Run INSIDE the Workshop, after the curl build (apps/curl), which provides libcurl.a and its deps:
#   workshop exec n900 -- bash -c 'VERSION=2.56.0 /project/apps/git/build.sh'
#   (or on the host: make -C apps/git build)
#
# git-remote-https is linked statically with libcurl, mbedTLS and zlib from apps/curl, so it does
# not depend on the old OpenSSL 0.9.8 of the device. The default CA bundle is the one baked into
# libcurl: /opt/curl/etc/ssl/cacert.pem (shipped by the "curl" package).
#
# Output (OUT=/project/build/out/git-$GIT_VERSION):
#   root/opt/git/...   installed tree (stripped, git-core programs are symlinks to "git")
set -euo pipefail

# GIT_VERSION is the older name of VERSION and is still accepted. VERSION itself is unset afterwards,
# so that it cannot leak into the git Makefile.
GIT_VERSION="${GIT_VERSION:-${VERSION:-2.56.0}}"
unset VERSION
CURL_VERSION="${CURL_VERSION:-8.23.0}"
MBEDTLS_VERSION="${MBEDTLS_VERSION:-3.6.7}"
ZLIB_VERSION="${ZLIB_VERSION:-1.3.2}"
PROJ=/project
DL="$PROJ/build/downloads"
SRCDIR="$PROJ/build/src"
SRC="$SRCDIR/git-$GIT_VERSION"
OUT="$PROJ/build/out/git-$GIT_VERSION"
CURLROOT="$PROJ/build/out/curl-$CURL_VERSION/root/opt/curl"
MBED="$PROJ/build/deps/mbedtls-$MBEDTLS_VERSION/usr/local"
ZDIR="$PROJ/build/deps/zlib-$ZLIB_VERSION"

[ -f "$CURLROOT/lib/libcurl.a" ] || { echo "Missing libcurl.a, run the curl build first (make -C apps/curl build)"; exit 1; }
mkdir -p "$DL" "$SRCDIR"

# 1. Source tarball (kernel.org), downloaded once. The hash is printed so it can be pinned.
if [ ! -s "$DL/git-$GIT_VERSION.tar.xz" ]; then
    curl -fL --retry 3 -o "$DL/git-$GIT_VERSION.tar.xz" "https://mirrors.edge.kernel.org/pub/software/scm/git/git-$GIT_VERSION.tar.xz"
fi
echo "sha256 $(sha256sum "$DL/git-$GIT_VERSION.tar.xz" | cut -d' ' -f1)  git-$GIT_VERSION.tar.xz"
rm -rf "$SRC" "$OUT"
tar -C "$SRCDIR" -xJf "$DL/git-$GIT_VERSION.tar.xz"
mkdir -p "$OUT/root"

# 2. Build. git builds in the source tree.
#  - uname_*: git decides platform settings from uname of the BUILD machine; pretend to be the device.
#  - CSPRNG_METHOD=urandom: the Linux default is getrandom(), which glibc 2.5 / kernel 2.6.28 lack.
#  - NO_RUST: Rust is enabled by default in git 2.5x, we do not have it.
#  - HAVE_SYNC_FILE_RANGE= (empty): glibc 2.5 has no sync_file_range() wrapper (added in 2.6).
#  - FSMONITOR_DAEMON_BACKEND= (empty): the built-in file system monitor daemon needs inotify_init1()
#    (glibc 2.9). Without it git simply has no "git fsmonitor--daemon", which is optional.
#  - LDFLAGS adds librt: clock_gettime() lives there in glibc 2.5 and git has no switch for it.
#    --no-as-needed keeps the library even though the objects that need it come later on the line.
#  - RUNTIME_PREFIX: git finds its helper programs relative to the binary, so /opt/git is relocatable.
#  - INSTALL_SYMLINKS: programs in git-core are symlinks to "git", so that stripping one file does not
#    break hardlinks and blow the package up.
#  - Everything optional is off (Perl, Python, Tcl/Tk, gettext, expat/WebDAV push, OpenSSL).
#  - libcurl is linked statically together with mbedTLS and zlib.
#  - MAEMO_DEPS makes our private zlib win over the old one in the sysroot (see scripts/maemo-gcc).
export MAEMO_DEPS="$ZDIR:$MBED"
MKFLAGS=(
    prefix=/opt/git
    uname_S=Linux uname_M=armv7l uname_R=2.6.28 uname_O=GNU/Linux
    CC="$PROJ/scripts/maemo-gcc" AR=arm-linux-gnueabi-ar STRIP=arm-linux-gnueabi-strip
    CFLAGS="-Os -include $PROJ/scripts/maemo-compat.h"
    RUNTIME_PREFIX=YesPlease INSTALL_SYMLINKS=YesPlease
    CSPRNG_METHOD=urandom NO_RUST=YesPlease
    HAVE_SYNC_FILE_RANGE= FSMONITOR_DAEMON_BACKEND= FSMONITOR_OS_SETTINGS=
    LDFLAGS="-Wl,--no-as-needed -lrt -Wl,--as-needed"
    NO_EXPAT=YesPlease NO_TCLTK=YesPlease NO_GETTEXT=YesPlease NO_PERL=YesPlease NO_PYTHON=YesPlease
    NO_OPENSSL=YesPlease
    CURL_CONFIG="$CURLROOT/bin/curl-config"
    CURL_CFLAGS="-I$CURLROOT/include -DCURL_STATICLIB"
    CURL_LDFLAGS="-L$CURLROOT/lib -lcurl -L$MBED/lib -lmbedtls -lmbedx509 -lmbedcrypto -L$ZDIR/lib -lz -lrt -lpthread"
)
make -C "$SRC" -j"$(nproc)" "${MKFLAGS[@]}" > "$OUT/make.log" 2>&1 \
    || { grep -E 'error|Error|undefined' "$OUT/make.log" | head -20; exit 1; }
make -C "$SRC" "${MKFLAGS[@]}" install DESTDIR="$OUT/root" >> "$OUT/make.log" 2>&1 \
    || { tail -20 "$OUT/make.log"; exit 1; }

# 3. Strip the real binaries (regular ELF files only; symlinks point at them).
find "$OUT/root/opt/git" -type f -print0 | while IFS= read -r -d '' f; do
    if [ "$(head -c4 "$f" | od -An -c | tr -d ' ')" = '177ELF' ]; then
        arm-linux-gnueabi-strip "$f"
    fi
done

echo "== Check"
G="$OUT/root/opt/git/bin/git"
file "$G" | cut -c1-140
arm-linux-gnueabi-readelf -d "$G" | grep NEEDED
echo -n "Highest glibc symbol (git): "
arm-linux-gnueabi-objdump -T "$G" | grep -oE 'GLIBC_[0-9.]+' | sort -uV | tail -1
H="$(find "$OUT/root/opt/git" -name git-remote-http -type f | head -1)"
if [ -n "$H" ]; then
    echo -n "Highest glibc symbol (git-remote-http): "
    arm-linux-gnueabi-objdump -T "$H" | grep -oE 'GLIBC_[0-9.]+' | sort -uV | tail -1
fi
du -sh "$OUT/root/opt/git"
ls -l "$G"
