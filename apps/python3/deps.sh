#!/bin/bash
# Static libraries for the optional Python modules: readline (+history), libffi (ctypes), bzip2 (bz2), xz (lzma).
# Run INSIDE the Workshop (build.sh calls it). Each library goes to build/deps/<name>-<version>/{include,lib}.
# All are built with -fPIC because the Python modules are shared objects (lib-dynload/*.so) that link them in.
# Needs: ncursesw (static, from apps/mutt) for readline.
set -euo pipefail
PROJ=/project
SR="$PROJ/sysroot"
DL="$PROJ/build/downloads"
SRCDIR="$PROJ/build/src"
DEPS="$PROJ/build/deps"
READLINE_V=8.2
FFI_V=3.4.6
BZIP2_V=1.0.8
XZ_V=5.4.7
mkdir -p "$DL" "$SRCDIR" "$DEPS"

fetch() { [ -s "$DL/$2" ] || curl -fL --retry 3 -o "$DL/$2" "$1"; echo "sha256 $(sha256sum "$DL/$2" | cut -d' ' -f1)  $2"; }
unpack() { rm -rf "$SRCDIR/$2"; mkdir -p "$SRCDIR/$2"; tar -C "$SRCDIR/$2" --strip-components=1 -xf "$DL/$1"; }
LOG="$PROJ/build/python3-deps.log"
: > "$LOG"
# configure-style build; extra arguments are passed to ./configure
cross_autotools() {   # name version
    local n=$1 v=$2; shift 2
    ( cd "$SRCDIR/$n-$v" \
      && CC="$PROJ/scripts/maemo-gcc" AR=arm-linux-gnueabi-ar RANLIB=arm-linux-gnueabi-ranlib \
         CFLAGS="-Os -fPIC -include $PROJ/scripts/maemo-compat.h" \
         ./configure --host=arm-linux-gnueabi --build="$(gcc -dumpmachine)" --prefix="$DEPS/$n-$v" \
             --enable-static --disable-shared "$@" \
      && make -j"$(nproc)" && make install ) >> "$LOG" 2>&1 || { tail -30 "$LOG"; exit 1; }
}

if [ ! -s "$DEPS/libffi-$FFI_V/lib/libffi.a" ]; then
    echo "== libffi $FFI_V"
    fetch "https://github.com/libffi/libffi/releases/download/v$FFI_V/libffi-$FFI_V.tar.gz" "libffi-$FFI_V.tar.gz"
    unpack "libffi-$FFI_V.tar.gz" "libffi-$FFI_V"
    cross_autotools libffi "$FFI_V" --disable-docs
    # libffi installs into lib/ or lib/<triplet>/ depending on the version; python's configure expects lib/.
    find "$DEPS/libffi-$FFI_V" -name 'libffi.a' ! -path "$DEPS/libffi-$FFI_V/lib/libffi.a" -exec cp {} "$DEPS/libffi-$FFI_V/lib/" \;
    [ -s "$DEPS/libffi-$FFI_V/include/ffi.h" ] || cp "$DEPS/libffi-$FFI_V"/lib/libffi-*/include/*.h "$DEPS/libffi-$FFI_V/include/" 2>/dev/null || true
fi

if [ ! -s "$DEPS/xz-$XZ_V/lib/liblzma.a" ]; then
    echo "== xz $XZ_V (liblzma)"
    fetch "https://github.com/tukaani-project/xz/releases/download/v$XZ_V/xz-$XZ_V.tar.xz" "xz-$XZ_V.tar.xz"
    unpack "xz-$XZ_V.tar.xz" "xz-$XZ_V"
    cross_autotools xz "$XZ_V" --disable-xz --disable-xzdec --disable-lzmadec --disable-lzmainfo --disable-scripts --disable-doc --disable-nls
fi

if [ ! -s "$DEPS/bzip2-$BZIP2_V/lib/libbz2.a" ]; then
    echo "== bzip2 $BZIP2_V"
    fetch "https://sourceware.org/pub/bzip2/bzip2-$BZIP2_V.tar.gz" "bzip2-$BZIP2_V.tar.gz"
    unpack "bzip2-$BZIP2_V.tar.gz" "bzip2-$BZIP2_V"
    # No configure script: plain Makefile, only the library.
    ( cd "$SRCDIR/bzip2-$BZIP2_V" \
      && make libbz2.a CC="$PROJ/scripts/maemo-gcc" AR=arm-linux-gnueabi-ar RANLIB=arm-linux-gnueabi-ranlib \
              CFLAGS="-Os -fPIC -D_FILE_OFFSET_BITS=64 -include $PROJ/scripts/maemo-compat.h" \
      && mkdir -p "$DEPS/bzip2-$BZIP2_V/lib" "$DEPS/bzip2-$BZIP2_V/include" \
      && cp libbz2.a "$DEPS/bzip2-$BZIP2_V/lib/" && cp bzlib.h "$DEPS/bzip2-$BZIP2_V/include/" ) >> "$LOG" 2>&1 || { tail -30 "$LOG"; exit 1; }
fi

if [ ! -s "$DEPS/readline-$READLINE_V/lib/libreadline.a" ]; then
    echo "== readline $READLINE_V"
    fetch "https://ftp.gnu.org/gnu/readline/readline-$READLINE_V.tar.gz" "readline-$READLINE_V.tar.gz"
    unpack "readline-$READLINE_V.tar.gz" "readline-$READLINE_V"
    # Cross-compiling: the configure tests that would have to run on the target get their answers here.
    bash_cv_func_sigsetjmp=present bash_cv_func_ctype_nonascii=no bash_cv_wcwidth_broken=no \
    MAEMO_DEPS="$SR/usr" cross_autotools readline "$READLINE_V" --with-curses
fi
ls -l "$DEPS"/libffi-*/lib/libffi.a "$DEPS"/xz-*/lib/liblzma.a "$DEPS"/bzip2-*/lib/libbz2.a "$DEPS"/readline-*/lib/lib{readline,history}.a
