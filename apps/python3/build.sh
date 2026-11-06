#!/bin/bash
# Cross-build Python 3.11 for Maemo 5 (armel, glibc 2.5, kernel 2.6.28). Run INSIDE the Workshop:
#   make -C apps/python3 build      (needs: make -C apps/openssl build; zlib from apps/curl; ncurses from apps/mutt)
# Output: /project/build/out/python3-$VERSION/root/opt/python3/{bin,lib}
#
# What differs from a naive "./configure --host=arm-linux-gnueabihf" (see DOC/python3-repo-review.md):
#  - armel + the wrapper scripts/maemo-gcc with the Fremantle sysroot (glibc 2.5), not Ubuntu's own glibc 2.39,
#  - OpenSSL 3 (static) for the ssl module, zlib 1.3, SQLite (own, the device has 3.6 and Python needs 3.7.15+),
#    wide-character ncurses (static),
#  - no PGO (--enable-optimizations needs to RUN the binary), IPv6 kept (ac_cv_buggy_getaddrinfo=no),
#  - a native "build python" of the same version, bytecode compiled at build time (the target has a slow CPU).
set -euo pipefail

VERSION="${VERSION:-3.11.18}"
SSLV="${SSLV:-3.5.9}"
SQLV="${SQLV:-3500400}"   # SQLite 3.50.4
PROJ=/project
SR="$PROJ/sysroot"
DL="$PROJ/build/downloads"
SRCDIR="$PROJ/build/src"
DEPS="$PROJ/build/deps"
OUT="$PROJ/build/out/python3-$VERSION"
HOSTPY="$DEPS/python-host-$VERSION"
SSL="$DEPS/openssl-$SSLV"
ZLIB="$DEPS/zlib-1.3.2"
NCW="$DEPS/ncursesw-static"
SQL="$DEPS/sqlite-$SQLV"
FFI="$DEPS/libffi-3.4.6"; XZ="$DEPS/xz-5.4.7"; BZ="$DEPS/bzip2-1.0.8"; RL="$DEPS/readline-8.2"   # versions: deps.sh

[ -s "$SSL/lib/libssl.a" ] || { echo "Missing OpenSSL, run: make -C apps/openssl build"; exit 1; }
[ -s "$ZLIB/lib/libz.a" ] || { echo "Missing zlib, run: make -C apps/curl build"; exit 1; }
mkdir -p "$DL" "$SRCDIR" "$OUT"
fetch() { [ -s "$DL/$2" ] || curl -fL --retry 3 -o "$DL/$2" "$1"; echo "sha256 $(sha256sum "$DL/$2" | cut -d' ' -f1)  $2"; }
fetch "https://www.python.org/ftp/python/$VERSION/Python-$VERSION.tgz" "Python-$VERSION.tgz"
fetch "https://www.sqlite.org/2025/sqlite-amalgamation-$SQLV.zip" "sqlite-amalgamation-$SQLV.zip"

# ---- 1. native "build python" (same version): runs the freeze step and compiles the bytecode
if [ ! -x "$HOSTPY/bin/python3.11" ]; then
    echo "== host python $VERSION"
    rm -rf "$SRCDIR/python-host-$VERSION"; mkdir -p "$SRCDIR/python-host-$VERSION"
    tar -C "$SRCDIR/python-host-$VERSION" --strip-components=1 -xzf "$DL/Python-$VERSION.tgz"
    ( cd "$SRCDIR/python-host-$VERSION" && ./configure --prefix="$HOSTPY" --without-ensurepip > "$OUT/host-configure.log" 2>&1 \
        && make -j"$(nproc)" > "$OUT/host-make.log" 2>&1 && make install > "$OUT/host-install.log" 2>&1 ) \
        || { tail -20 "$OUT/host-make.log" 2>/dev/null; exit 1; }
fi

# ---- 2. SQLite amalgamation as a static library (own copy, see above)
if [ ! -s "$SQL/lib/libsqlite3.a" ]; then
    echo "== sqlite $SQLV"
    rm -rf "$SQL" "$SRCDIR/sqlite-amalgamation-$SQLV"; mkdir -p "$SQL/lib" "$SQL/include"
    python3 -c "import sys, zipfile; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])" "$DL/sqlite-amalgamation-$SQLV.zip" "$SRCDIR"
    ( cd "$SRCDIR/sqlite-amalgamation-$SQLV" \
      && "$PROJ/scripts/maemo-gcc" -Os -fPIC -DSQLITE_THREADSAFE=1 -DSQLITE_ENABLE_FTS5 -DSQLITE_OMIT_LOAD_EXTENSION -c sqlite3.c -o sqlite3.o \
      && arm-linux-gnueabi-ar rcs "$SQL/lib/libsqlite3.a" sqlite3.o && cp sqlite3.h sqlite3ext.h "$SQL/include/" )
fi

# ---- 2b. static libraries of the optional modules (readline, ctypes/libffi, bz2, lzma)
bash "$PROJ/apps/python3/deps.sh" > "$OUT/deps.log" 2>&1 || { tail -30 "$OUT/deps.log"; exit 1; }

# ---- 3. static panel library next to ncursesw (the device has no libncursesw/libpanelw)
mkdir -p "$NCW/lib"
cp "$SR/usr/lib/libncursesw.a" "$SR/usr/lib/libpanelw.a" "$NCW/lib/"

# ---- 4. cross build
echo "== python $VERSION for the N900"
rm -rf "$SRCDIR/python3-$VERSION" "$OUT/root"
mkdir -p "$SRCDIR/python3-$VERSION" "$OUT/root"
tar -C "$SRCDIR/python3-$VERSION" --strip-components=1 -xzf "$DL/Python-$VERSION.tgz"
cd "$SRCDIR/python3-$VERSION"

export MAEMO_DEPS="$SSL:$ZLIB:$SQL:$NCW:$FFI:$XZ:$BZ:$RL"
export PKG_CONFIG_LIBDIR=/nonexistent PKG_CONFIG_PATH=
# - ac_cv_file__dev_ptmx=yes: the N900 has /dev/ptmx (cross builds cannot test it); ac_cv_file__dev_ptc=no is the usual answer.
# - ac_cv_buggy_getaddrinfo=no: the configure test would have to run on the target; keeps IPv6.
# - CURSES_*/PANEL_*: no pkg-config for ncursesw in the sysroot.
# - LIBFFI_*/LIBLZMA_*: the private static libraries from deps.sh (bz2 and readline are found through MAEMO_DEPS).
# - LIBSQLITE3_*: the private SQLite (static); -ldl/-lpthread/-lm are needed by it.
CC="$PROJ/scripts/maemo-gcc" CXX=false AR=arm-linux-gnueabi-ar RANLIB=arm-linux-gnueabi-ranlib \
READELF=arm-linux-gnueabi-readelf \
CFLAGS="-O2 -include $PROJ/scripts/maemo-compat.h" \
CURSES_CFLAGS="-I$SR/usr/include/ncursesw" CURSES_LIBS="-lncursesw" \
PANEL_CFLAGS="-I$SR/usr/include/ncursesw" PANEL_LIBS="-lpanelw -lncursesw" \
LIBFFI_CFLAGS="-I$FFI/include" LIBFFI_LIBS="-L$FFI/lib -lffi" \
LIBLZMA_CFLAGS="-I$XZ/include" LIBLZMA_LIBS="-L$XZ/lib -llzma" \
LIBSQLITE3_CFLAGS="-I$SQL/include" LIBSQLITE3_LIBS="-lsqlite3 -ldl -lpthread -lm" \
ac_cv_file__dev_ptmx=yes ac_cv_file__dev_ptc=no ac_cv_buggy_getaddrinfo=no \
./configure --host=arm-linux-gnueabi --build="$(gcc -dumpmachine)" \
    --with-build-python="$HOSTPY/bin/python3.11" \
    --prefix=/opt/python3 --with-openssl="$SSL" --without-ensurepip \
    > "$OUT/configure.log" 2>&1 || { tail -30 "$OUT/configure.log"; exit 1; }
echo "== configured"
# BLDSHARED: the Makefile hands it to setup.py as LDSHARED; our wrapper adds the libraries for readline and _ctypes (ldshared.sh)
make -j"$(nproc)" BLDSHARED="$PROJ/apps/python3/ldshared.sh -shared" > "$OUT/make.log" 2>&1 || { grep -E "error|Error" "$OUT/make.log" | head -30; exit 1; }
make install DESTDIR="$OUT/root" > "$OUT/install.log" 2>&1 || { tail -20 "$OUT/install.log"; exit 1; }
grep -E "^(Failed|The necessary bits|Following modules|The following modules)" -A4 "$OUT/make.log" | head -20 || true

# ---- 5. slim down and precompile
P="$OUT/root/opt/python3"
arm-linux-gnueabi-strip "$P/bin/python3.11" || true
find "$P/lib/python3.11/lib-dynload" -name '*.so' -exec arm-linux-gnueabi-strip --strip-unneeded {} +
rm -rf "$P/lib/python3.11/test" "$P/lib/python3.11/idlelib" "$P/lib/python3.11/tkinter" "$P/lib/python3.11/turtledemo" \
       "$P/lib/python3.11/lib2to3/tests" "$P/lib/python3.11/unittest/test" "$P/lib/python3.11/__pycache__"
rm -f "$P/lib/libpython3.11.a"   # static library for embedding, 30 MB
rm -rf "$P/lib/python3.11/config-3.11-"* "$P/lib/pkgconfig" "$P/share" "$P/include"
# pip: no ensurepip at runtime (it would need the target python at build time); unpack the bundled wheel instead.
# (The system python3 does it: the host build python above has no zlib module.)
python3 - "$SRCDIR/python3-$VERSION/Lib/ensurepip/_bundled" "$P/lib/python3.11/site-packages" <<'PY'
import glob, sys, zipfile
whl = glob.glob(sys.argv[1] + "/pip-*.whl")[0]
zipfile.ZipFile(whl).extractall(sys.argv[2])
print("pip:", whl.split("/")[-1])
PY
printf '#!/opt/python3/bin/python3.11\nimport sys\nfrom pip._internal.cli.main import main\nif __name__ == "__main__":\n    sys.exit(main())\n' > "$P/bin/pip3"
chmod 755 "$P/bin/pip3"
# Bytecode of 3.11 is the same on every architecture, so the native python can precompile the target's library.
"$HOSTPY/bin/python3.11" -m compileall -q -j0 "$P/lib/python3.11" > /dev/null || true
echo "== Check"
file "$P/bin/python3.11"
du -sh "$P"
