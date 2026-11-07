#!/bin/bash
# Cross-build tmux for Maemo 5 (armel, glibc 2.5). Run INSIDE the Workshop:
#   workshop exec n900 -- bash -c 'VERSION=3.8 /project/apps/tmux/build.sh'   (or: make -C apps/tmux build)
# Output: /project/build/out/tmux-$VERSION/root/opt/tmux/{bin,share}   (installed tree)
#
# libevent (the only library the phone does not have) is built statically into build/deps and linked into tmux; ncurses comes from the
# device (libncurses5 5.7, the sysroot has the same version). tmux itself is dynamically linked against glibc 2.5.
set -euo pipefail

VERSION="${VERSION:-3.8}"
LEV="${LIBEVENT_VERSION:-2.1.12}"
PROJ=/project
SR="$PROJ/sysroot"
DL="$PROJ/build/downloads"
SRCDIR="$PROJ/build/src"
OUT="$PROJ/build/out/tmux-$VERSION"
DEP="$PROJ/build/deps/libevent-$LEV"
CC="$PROJ/scripts/maemo-gcc"

[ -d "$SR/usr/include" ] || { echo "Missing sysroot, run: make sysroot"; exit 1; }
mkdir -p "$DL" "$SRCDIR"

# 1. libevent, static. Without eventfd: the glibc 2.5 of the phone has no eventfd() wrapper (GLIBC_2.7), libevent then wakes up through a pipe.
if [ ! -f "$DEP/lib/libevent.a" ]; then
    f="libevent-$LEV-stable.tar.gz"
    [ -s "$DL/$f" ] || curl -fL --retry 3 -o "$DL/$f" "https://github.com/libevent/libevent/releases/download/release-$LEV-stable/$f"
    echo "sha256 $(sha256sum "$DL/$f" | cut -d' ' -f1)  $f"
    rm -rf "$SRCDIR/libevent-$LEV-stable" "$DEP"
    tar -C "$SRCDIR" -xzf "$DL/$f"
    ( cd "$SRCDIR/libevent-$LEV-stable"
      ./configure --host=arm-linux-gnueabi --build="$(gcc -dumpmachine)" --prefix="$DEP" \
          --disable-shared --enable-static --disable-openssl --disable-samples --disable-libevent-regress --disable-debug-mode \
          ac_cv_header_sys_eventfd_h=no ac_cv_func_eventfd=no \
          CC="$CC" AR=arm-linux-gnueabi-ar RANLIB=arm-linux-gnueabi-ranlib CFLAGS="-Os -include $PROJ/scripts/maemo-compat.h" \
          > "$PROJ/build/libevent-configure.log" 2>&1 || { tail -20 "$PROJ/build/libevent-configure.log"; exit 1; }
      make -j"$(nproc)" > "$PROJ/build/libevent-build.log" 2>&1 || { tail -20 "$PROJ/build/libevent-build.log"; exit 1; }
      make install >> "$PROJ/build/libevent-build.log" 2>&1 )
fi

# 2. tmux
f="tmux-$VERSION.tar.gz"
[ -s "$DL/$f" ] || curl -fL --retry 3 -o "$DL/$f" "https://github.com/tmux/tmux/releases/download/$VERSION/$f"
echo "sha256 $(sha256sum "$DL/$f" | cut -d' ' -f1)  $f"
rm -rf "$SRCDIR/tmux-$VERSION" "$OUT"
tar -C "$SRCDIR" -xzf "$DL/$f"
mkdir -p "$OUT/root"
cd "$SRCDIR/tmux-$VERSION"
# The device has the plain libncurses5 (no pkg-config files in the sysroot): the flags are given directly.
./configure --host=arm-linux-gnueabi --build="$(gcc -dumpmachine)" --prefix=/opt/tmux \
    CC="$CC" CFLAGS="-Os -D_GNU_SOURCE -include $PROJ/scripts/maemo-compat.h" \
    LIBEVENT_CFLAGS="-I$DEP/include" LIBEVENT_LIBS="-L$DEP/lib -levent" \
    LIBNCURSES_CFLAGS="-I$SR/usr/include" LIBNCURSES_LIBS="-lncurses" \
    > "$OUT/configure.log" 2>&1 || { tail -30 "$OUT/configure.log"; exit 1; }
make -j"$(nproc)" > "$OUT/make.log" 2>&1 || { grep -E 'error|Error' "$OUT/make.log" | head -20; tail -15 "$OUT/make.log"; exit 1; }
make install-strip DESTDIR="$OUT/root" >> "$OUT/make.log" 2>&1 || { tail -20 "$OUT/make.log"; exit 1; }

BIN="$OUT/root/opt/tmux/bin/tmux"
echo "== Check"
file "$BIN" | cut -c1-140
arm-linux-gnueabi-readelf -d "$BIN" | grep NEEDED
echo -n "Highest glibc symbol: "
arm-linux-gnueabi-objdump -T "$BIN" | grep -oE 'GLIBC_[0-9.]+' | sort -uV | tail -1
ls -l "$BIN"
