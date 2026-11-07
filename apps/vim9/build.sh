#!/bin/bash
# Cross-build Vim 9 for Maemo 5 (armel, glibc 2.5). Run INSIDE the Workshop:
#   workshop exec n900 -- bash -c 'VERSION=9.2.1302 /project/apps/vim9/build.sh'   (or: make -C apps/vim9 build)
# Output: /project/build/out/vim9-$VERSION/root/opt/vim9/{bin,share}   (installed tree)
#
# The device has vim 7.2 (package vim, /opt/maemo/usr/bin/vim, /usr/bin/vim and /usr/bin/vi through alternatives). This build is
# installed under /opt/vim9 and is started as vim9, so the system vim stays untouched (like htop3 next to htop).
# Features "normal", no GUI/X11, UTF-8, terminal via the plain ncurses of the sysroot (the device has libncurses5).
set -euo pipefail

VERSION="${VERSION:-9.2.1302}"
PROJ=/project
SR="$PROJ/sysroot"
SRC="$PROJ/build/upstream/vim"
WORK="$PROJ/build/obj/vim9-$VERSION"
OUT="$PROJ/build/out/vim9-$VERSION"

[ -d "$SR/usr/include" ] || { echo "Missing sysroot, run: make sysroot"; exit 1; }
if [ ! -d "$SRC/.git" ]; then
    mkdir -p "$(dirname "$SRC")"
    git clone -q --depth 1 --branch "v$VERSION" https://github.com/vim/vim.git "$SRC"
fi
git -C "$SRC" fetch -q --depth 1 origin "tag" "v$VERSION" 2>/dev/null || true
git -C "$SRC" checkout -q -f "v$VERSION"

# Vim builds in its source tree: work on a copy.
rm -rf "$WORK" "$OUT"
mkdir -p "$OUT/root"
cp -a "$SRC" "$WORK"
cd "$WORK/src"

# configure cannot run test programs when cross-compiling: the answers (as on a normal Linux with glibc) are given here.
# vim_cv_timer_create=no: timer_create needs -lrt and is not needed for the terminal version.
export vim_cv_toupper_broken=no vim_cv_terminfo=yes vim_cv_tgetent=zero vim_cv_getcwd_broken=no \
       vim_cv_stat_ignores_slash=no vim_cv_memmove_handles_overlap=yes vim_cv_tty_group=world vim_cv_tty_mode=0620 \
       vim_cv_timer_create=no vim_cv_timer_create_with_lrt=no ac_cv_sizeof_int=4 ac_cv_small_wchar_t=no ac_cv_func_fchdir=yes
./configure \
    --host=arm-linux-gnueabi --build="$(gcc -dumpmachine)" \
    --prefix=/opt/vim9 \
    --with-features=normal --disable-gui --without-x --enable-multibyte \
    --with-tlib=ncurses --disable-nls --disable-gpm --disable-sysmouse --disable-selinux --disable-acl --disable-canberra \
    --disable-netbeans --disable-channel --disable-terminal \
    CC="$PROJ/scripts/maemo-gcc" \
    CFLAGS="-Os -include $PROJ/scripts/maemo-compat.h" \
    > "$OUT/configure.log" 2>&1 || { tail -30 "$OUT/configure.log"; exit 1; }
make -j"$(nproc)" > "$OUT/make.log" 2>&1 || { grep -E 'error|Error' "$OUT/make.log" | head -20; exit 1; }
make install STRIP=arm-linux-gnueabi-strip DESTDIR="$OUT/root" >> "$OUT/make.log" 2>&1 || { tail -20 "$OUT/make.log"; exit 1; }

BIN="$OUT/root/opt/vim9/bin/vim"
arm-linux-gnueabi-strip "$BIN" 2>/dev/null || true
echo "== Check"
file "$BIN" | cut -c1-140
arm-linux-gnueabi-readelf -d "$BIN" | grep NEEDED
echo -n "Highest glibc symbol: "
arm-linux-gnueabi-objdump -T "$BIN" | grep -oE 'GLIBC_[0-9.]+' | sort -uV | tail -1
du -sh "$OUT/root/opt/vim9"
ls -l "$BIN"
