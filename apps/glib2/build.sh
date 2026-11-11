#!/bin/bash
# Cross-build GLib 2.66 (static libglib/gobject/gmodule/gthread/gio) for Maemo 5 (armel, glibc 2.5).
# Run INSIDE the Workshop:  make -C apps/glib2 build
#
# Why: the phone has GLib 2.20. Programs that need a newer GLib (irssi, mc, ...) link this copy statically, so the
# system GLib that Hildon runs on stays untouched. Output: /project/build/deps/glib2-$VERSION/{include,lib}
# (use through MAEMO_DEPS, see scripts/maemo-gcc, and PKG_CONFIG_PATH=$PREFIX/lib/pkgconfig).
set -euo pipefail

VERSION="${VERSION:-2.66.8}"
PROJ=/project
SR="$PROJ/sysroot"
DL="$PROJ/build/downloads"
SRCDIR="$PROJ/build/src"
PREFIX="$PROJ/build/deps/glib2-$VERSION"
OBJ="$PROJ/build/obj/glib2-$VERSION"
FFI="$PROJ/build/deps/libffi-3.4.6"
ZLIB="$PROJ/build/deps/zlib-1.3.2"

[ -d "$SR/usr/include" ] || { echo "Missing sysroot, run: make sysroot"; exit 1; }
[ -f "$FFI/lib/libffi.a" ] && [ -f "$ZLIB/lib/libz.a" ] || { echo "Missing libffi or zlib in build/deps (built by apps/python3)"; exit 1; }
mkdir -p "$DL" "$SRCDIR"
f="glib-$VERSION.tar.xz"
[ -s "$DL/$f" ] || curl -fL --retry 3 -o "$DL/$f" "https://download.gnome.org/sources/glib/${VERSION%.*}/$f"
echo "sha256 $(sha256sum "$DL/$f" | cut -d' ' -f1)  $f"
rm -rf "$SRCDIR/glib-$VERSION" "$PREFIX" "$OBJ"
tar -C "$SRCDIR" -xJf "$DL/$f"

# GLib asks for a C++ compiler only for one check (ISO varargs macros in C++, true for any GCC). A cross C++ compiler
# cannot run its test program here, so the language is dropped and the check is answered with true.
python3 - "$SRCDIR/glib-$VERSION/meson.build" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p).read()
s = s.replace("project('glib', 'c', 'cpp',", "project('glib', 'c',", 1)
s = s.replace("cxx = meson.get_compiler('cpp')", "cxx = meson.get_compiler('c')", 1)
s, n = re.subn(r"g_have_iso_cxx_varargs = cxx\.compiles\(.*?name : 'ISO C99 varargs macros in C\+\+'\)", "g_have_iso_cxx_varargs = true", s, count=1, flags=re.S)
assert n == 1, "cxx check not found"
open(p, "w").write(s)
PY
# The test programs are not built (they need C++ and a dbus/libelf host); drop their subdirs.
grep -rl --include=meson.build -E "subdir\('(tests|fuzzing)'\)" "$SRCDIR/glib-$VERSION" | xargs sed -i -E "s/^([[:space:]]*)subdir\('(tests|fuzzing)'\)/\1# &/"
mkdir -p "$OBJ"

# Meson cross file. maemo-gcc brings sysroot, gold and the glibc 2.5 flags; qemu-user runs the configure-time test programs.
cat > "$OBJ/cross.ini" <<INI
[binaries]
c = '$PROJ/scripts/maemo-gcc'
ar = 'arm-linux-gnueabi-ar'
strip = 'arm-linux-gnueabi-strip'
pkg-config = 'pkg-config'
exe_wrapper = ['qemu-arm', '-L', '$SR']

[host_machine]
system = 'linux'
cpu_family = 'arm'
cpu = 'armv7'
endian = 'little'

[properties]
needs_exe_wrapper = true

[built-in options]
c_args = ['-Os', '-include', '$PROJ/scripts/maemo-compat.h']
pkg_config_path = ['$FFI/lib/pkgconfig', '$ZLIB/lib/pkgconfig']
INI

export MAEMO_DEPS="$FFI:$ZLIB"
cd "$SRCDIR/glib-$VERSION"
meson setup "$OBJ/b" --cross-file "$OBJ/cross.ini" --prefix "$PREFIX" --default-library=static \
    -Dinternal_pcre=true -Dlibmount=disabled -Dselinux=disabled -Dxattr=false -Dnls=disabled \
    -Dman=false -Dgtk_doc=false -Dinstalled_tests=false -Dfam=false \
    > "$OBJ/setup.log" 2>&1 || { tail -40 "$OBJ/setup.log"; exit 1; }
ninja -C "$OBJ/b" > "$OBJ/ninja.log" 2>&1 || { grep -E "error|FAILED" "$OBJ/ninja.log" | head -20; tail -5 "$OBJ/ninja.log"; exit 1; }
ninja -C "$OBJ/b" install > "$OBJ/install.log" 2>&1
echo "== Check"
ls -l "$PREFIX/lib"/*.a
