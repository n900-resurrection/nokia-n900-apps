#!/bin/bash
# Cross-build OpenSSH portable for Maemo 5 (armel, glibc 2.5, kernel 2.6.28). Run INSIDE the Workshop (make -C apps/openssh build).
# Output: /project/build/out/openssh-$VERSION/root/opt/openssh/{bin,sbin,libexec,etc,var}
# The system OpenSSH 5.1 of the phone is not touched: everything lives under /opt/openssh. OpenSSL 3 and zlib are linked statically.
set -euo pipefail

VERSION="${VERSION:-10.6p2}"
OPENSSL_VERSION="${OPENSSL_VERSION:-3.5.9}"
ZLIB_VERSION="${ZLIB_VERSION:-1.3.2}"
PROJ=/project
SR="$PROJ/sysroot"
DL="$PROJ/build/downloads"
SRCDIR="$PROJ/build/src"
OUT="$PROJ/build/out/openssh-$VERSION"
SSL="$PROJ/build/deps/openssl-$OPENSSL_VERSION"
ZDIR="$PROJ/build/deps/zlib-$ZLIB_VERSION"

[ -d "$SR/usr/include" ] || { echo "Missing sysroot, run: make sysroot"; exit 1; }
[ -s "$SSL/lib/libcrypto.a" ] || { echo "Missing $SSL, run: make openssl"; exit 1; }
[ -s "$ZDIR/lib/libz.a" ] || { echo "Missing $ZDIR (it is built by: make curl)"; exit 1; }
mkdir -p "$DL" "$SRCDIR"
f="openssh-$VERSION.tar.gz"
[ -s "$DL/$f" ] || curl -fL --retry 3 -o "$DL/$f" "https://cdn.openbsd.org/pub/OpenBSD/OpenSSH/portable/$f"
echo "sha256 $(sha256sum "$DL/$f" | cut -d' ' -f1)  $f"
rm -rf "$SRCDIR/openssh-$VERSION" "$OUT"
tar -C "$SRCDIR" -xzf "$DL/$f"
mkdir -p "$OUT/root"
cd "$SRCDIR/openssh-$VERSION"
export MAEMO_DEPS="$SSL:$ZDIR"
# The configure test "select works with rlimit" cannot run when cross compiling and then assumes "no", which rules out the rlimit sandbox.
# It works on Linux, so the cross compiling branch is changed to "yes".
# (the first assignment is the cross compiling branch)
sed -i '0,/select_works_with_rlimit=no/s//select_works_with_rlimit=yes/' configure
grep -n "select_works_with_rlimit=" configure | head -4
# --with-sandbox=rlimit: the privilege separation sandbox without seccomp (the 2.6.28 kernel has only the old strict seccomp mode).
# --without-pam: the phone has no PAM setup for it. --disable-strip: stripped below, make install would use the host strip.
./configure --host=arm-linux-gnueabi --build="$(gcc -dumpmachine)" --prefix=/opt/openssh --sysconfdir=/opt/openssh/etc \
    --with-ssl-dir="$SSL" --with-zlib="$ZDIR" --with-privsep-path=/opt/openssh/var/empty --with-pid-dir=/var/run \
    --with-sandbox=rlimit --without-pam --without-selinux --without-kerberos5 --without-libedit --without-audit \
    --disable-strip --disable-etc-default-login --disable-lastlog --disable-utmp --disable-utmpx --disable-wtmp --disable-wtmpx \
    CC="$PROJ/scripts/maemo-gcc" CFLAGS="-Os -D_GNU_SOURCE -include $PROJ/scripts/maemo-compat.h" LIBS="-lpthread -ldl" \
    > "$OUT/configure.log" 2>&1 || { tail -30 "$OUT/configure.log"; exit 1; }
make -j"$(nproc)" > "$OUT/make.log" 2>&1 || { grep -E 'error|Error' "$OUT/make.log" | head -20; tail -15 "$OUT/make.log"; exit 1; }
# install-nokeys: no host keys are generated at build time (the package postinst creates them on the phone)
make install-nokeys DESTDIR="$OUT/root" STRIP_OPT= >> "$OUT/make.log" 2>&1 || { tail -20 "$OUT/make.log"; exit 1; }
for b in "$OUT"/root/opt/openssh/bin/* "$OUT"/root/opt/openssh/sbin/* "$OUT"/root/opt/openssh/libexec/*; do
    [ -f "$b" ] && [ ! -L "$b" ] && arm-linux-gnueabi-strip "$b" || true
done
echo "== Check"
for b in bin/ssh sbin/sshd; do
    BIN="$OUT/root/opt/openssh/$b"
    file "$BIN" | cut -c1-120
    arm-linux-gnueabi-readelf -d "$BIN" | grep NEEDED | tr '\n' ' '; echo
    echo -n "Highest glibc symbol: "
    arm-linux-gnueabi-objdump -T "$BIN" | grep -oE 'GLIBC_[0-9.]+' | sort -uV | tail -1
done
ls -l "$OUT"/root/opt/openssh/bin "$OUT"/root/opt/openssh/sbin
