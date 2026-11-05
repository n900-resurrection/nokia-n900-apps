#!/bin/bash
# Cross-build Bash 5.x for Maemo 5 (armel, glibc 2.5). Run INSIDE the Workshop:
#   workshop exec n900 -- bash -c 'VERSION=5.3 /project/apps/bash/build.sh'   (or: make -C apps/bash build)
# Output: /project/build/out/bash-$VERSION/bash   (stripped binary)
#
# The device ships bash 3.2 (/bin/bash) and a bash4 package; this one is installed next to them
# in /opt/bash5 and never replaces /bin/bash. Plain ncurses (termcap) is linked dynamically from
# the system libncurses5. Readline is the copy bundled with bash.
set -euo pipefail

VERSION="${VERSION:-5.3}"
PROJ=/project
SR="$PROJ/sysroot"
DL="$PROJ/build/downloads"
SRCDIR="$PROJ/build/src"
OUT="$PROJ/build/out/bash-$VERSION"
OBJ="$PROJ/build/obj/bash-$VERSION"

[ -d "$SR/usr/include" ] || { echo "Missing sysroot, run: make sysroot"; exit 1; }
mkdir -p "$DL" "$SRCDIR"
f="bash-$VERSION.tar.gz"
[ -s "$DL/$f" ] || curl -fL --retry 3 -o "$DL/$f" "https://ftp.gnu.org/gnu/bash/$f"
echo "sha256 $(sha256sum "$DL/$f" | cut -d' ' -f1)  $f"
rm -rf "$SRCDIR/bash-$VERSION" "$OBJ" "$OUT"
tar -C "$SRCDIR" -xzf "$DL/$f"
mkdir -p "$OBJ" "$OUT/root"
cd "$OBJ"

# - bash_cv_*: values that configure cannot test when cross-compiling (it cannot run programs).
#   They are the answers for glibc on Linux.
# - --without-bash-malloc: use the malloc of glibc.
# - --disable-nls: no gettext, the device has none.
# - O_CLOEXEC etc. come from scripts/maemo-compat.h (glibc 2.5 headers lack them).
export bash_cv_getcwd_malloc=yes bash_cv_job_control_missing=present bash_cv_sys_named_pipes=present \
       bash_cv_func_sigsetjmp=present bash_cv_func_strcoll_broken=no bash_cv_dup2_broken=no \
       bash_cv_pgrp_pipe=no bash_cv_printf_a_format=yes bash_cv_wcwidth_broken=no \
       bash_cv_unusable_rtsigs=no bash_cv_sys_siglist=yes bash_cv_under_sys_siglist=yes \
       bash_cv_ulimit_maxfds=yes bash_cv_func_ctype_nonascii=no bash_cv_must_reinstall_sighandlers=no \
       bash_cv_opendir_not_robust=no bash_cv_getenv_redef=yes bash_cv_fnmatch_equiv_fallback=no
"$SRCDIR/bash-$VERSION/configure" \
    --host=arm-linux-gnueabi --build="$(gcc -dumpmachine)" \
    --prefix=/opt/bash5 \
    --without-bash-malloc --disable-nls --with-curses \
    CC="$PROJ/scripts/maemo-gcc" \
    CFLAGS="-Os -include $PROJ/scripts/maemo-compat.h" \
    > "$OUT/configure.log" 2>&1 || { tail -30 "$OUT/configure.log"; exit 1; }
# The wrapper puts the sysroot -L before ours, so the old system libreadline would win over the
# bundled one; name the bundled archives explicitly.
make -j"$(nproc)" READLINE_LIB="$OBJ/lib/readline/libreadline.a" HISTORY_LIB="$OBJ/lib/readline/libhistory.a" > "$OUT/make.log" 2>&1 || { grep -E 'error|Error' "$OUT/make.log" | head -20; exit 1; }
arm-linux-gnueabi-strip -o "$OUT/bash" bash

echo "== Check"
file "$OUT/bash" | cut -c1-140
arm-linux-gnueabi-readelf -d "$OUT/bash" | grep NEEDED
echo -n "Highest glibc symbol: "
arm-linux-gnueabi-objdump -T "$OUT/bash" | grep -oE 'GLIBC_[0-9.]+' | sort -uV | tail -1
ls -l "$OUT/bash"
