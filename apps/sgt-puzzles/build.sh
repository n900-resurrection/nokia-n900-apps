#!/bin/bash
# Cross-build Simon Tatham's Portable Puzzle Collection (GTK 2 front end) for Maemo 5 (armel, glibc 2.5, GTK 2.14). Run INSIDE the Workshop:
#   workshop exec n900 -- bash -c 'VERSION=20250730 /project/apps/sgt-puzzles/build.sh'   (or: make -C apps/sgt-puzzles build)
# Output: /project/build/out/sgt-puzzles-$VERSION/root/opt/sgt-puzzles/bin/sgt-<puzzle> (every puzzle is its own program, stripped)
#
# Source: the Debian archive copy of the upstream snapshot (sgt-puzzles_<VERSION>.<commit>.orig.tar.xz), so that the file does not change.
# What is on and off:
#  - GTK 2 (PUZZLES_GTK_VERSION=2): the sysroot has GTK 2.14 and Hildon, no GTK 3.
#  - no icons: the upstream build draws them by running preliminary puzzle binaries on the build host, which a cross build cannot do (no-icon.c is used);
#    the menu icon is drawn by apps/sgt-puzzles/make-icon.sh.
#  - shim/tgmath.h: <tgmath.h> of glibc 2.5 does not compile with GCC 13 (plain <math.h> is enough for the puzzles).
#  - gdk-key-compat.h (made here): the GDK_KEY_* names of GTK 2.22 for the GDK_* symbols of GTK 2.14, and gtk_widget_set_can_default of GTK 2.18.
#  - no documentation (halibut), no unfinished puzzles; every puzzle program is called sgt-<name> (NAME_PREFIX) so that it cannot clash with another program.
set -euo pipefail

VERSION="${VERSION:-20250730}"
COMMIT="${COMMIT:-a7c7826}"
PROJ=/project
SR="$PROJ/sysroot"
DL="$PROJ/build/downloads"
SRCDIR="$PROJ/build/src"
OBJ="$PROJ/build/obj/sgt-puzzles-$VERSION"
OUT="$PROJ/build/out/sgt-puzzles-$VERSION"

[ -f "$SR/usr/lib/pkgconfig/gtk+-2.0.pc" ] || { echo "Missing GTK 2 in the sysroot, run: make sysroot"; exit 1; }
command -v cmake >/dev/null || { echo "Missing cmake in the workshop, run: make toolchain"; exit 1; }
mkdir -p "$DL" "$SRCDIR"
f="sgt-puzzles_$VERSION.$COMMIT.orig.tar.xz"
[ -s "$DL/$f" ] || curl -fL --retry 3 -o "$DL/$f" "https://deb.debian.org/debian/pool/main/s/sgt-puzzles/$f"
echo "sha256 $(sha256sum "$DL/$f" | cut -d' ' -f1)  $f"
rm -rf "$SRCDIR/sgt-puzzles-$VERSION" "$OBJ" "$OUT"
mkdir -p "$SRCDIR/sgt-puzzles-$VERSION" "$OBJ" "$OUT/root"
tar -C "$SRCDIR/sgt-puzzles-$VERSION" --strip-components=1 -xJf "$DL/$f"

# Full screen (800x480) on the phone: the puzzles fit their tiles to the window, so a full screen window gives big tiles for the fingers; the menu bar stays
# (Game > Exit closes it). SGT_WINDOWED=1 in the environment gives the normal window.
python3 - "$SRCDIR/sgt-puzzles-$VERSION/gtk.c" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
old = "    gtk_widget_show(fe->area);\n    gtk_widget_show(fe->window);\n"
assert s.count(old) == 1
s = s.replace(old, old + "    if (!getenv(\"SGT_WINDOWED\")) gtk_window_fullscreen(GTK_WINDOW(fe->window));\n"
              "    if (fe->menubar) g_signal_connect(fe->menubar, \"deactivate\", G_CALLBACK(maemo_menu_closed), fe);\n")
# After a menu was closed the board in the full screen window drifted up (the picture changed without any expose event, so it is the compositing of the
# phone): a complete redraw of the window, at once and 150 ms later, puts it right.
helper = """static gboolean maemo_redraw_later(gpointer data)
{
    frontend *fe = (frontend *)data;
    gtk_widget_queue_draw(fe->window);
    return FALSE;
}

static void maemo_menu_closed(GtkMenuShell *shell, gpointer data)
{
    frontend *fe = (frontend *)data;
    gtk_widget_queue_draw(fe->window);
    g_timeout_add(150, maemo_redraw_later, fe);
}

"""
mark = "static void resize_fe(frontend *fe)\n{"
assert s.count(mark) == 1
s = s.replace(mark, helper + mark)
open(p, 'w').write(s)
PY

# GTK 2.14 (Maemo 5) has the key symbols as GDK_Escape; the puzzles use the names GDK_KEY_Escape of GTK 2.22 and later: a header that maps them (macros, so
# the order of the includes does not matter), made from the list of gdkkeysyms.h of the sysroot
mkdir -p "$OBJ/compat"
sed -n 's/^#define GDK_\([A-Za-z0-9_]*\)[ \t][ \t]*0x.*/#ifndef GDK_KEY_\1\n#define GDK_KEY_\1 GDK_\1\n#endif/p' "$SR/usr/include/gtk-2.0/gdk/gdkkeysyms.h" > "$OBJ/compat/gdk-key-compat.h"
# GTK 2.18 functions that GTK 2.14 lacks (the puzzles call them): the old flag macros do the same
cat >> "$OBJ/compat/gdk-key-compat.h" <<'EOT'
#define gtk_widget_set_can_default(w, b) do { if (b) GTK_WIDGET_SET_FLAGS((w), GTK_CAN_DEFAULT); else GTK_WIDGET_UNSET_FLAGS((w), GTK_CAN_DEFAULT); } while (0)
EOT
[ -s "$OBJ/compat/gdk-key-compat.h" ] || { echo "No key symbols found in gdkkeysyms.h"; exit 1; }

# the toolchain file: scripts/maemo-gcc (the sysroot, glibc 2.5 headers, gold) and pkg-config of the sysroot
cat > "$OBJ/toolchain.cmake" <<EOF
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR arm)
set(CMAKE_C_COMPILER $PROJ/scripts/maemo-gcc)
set(CMAKE_C_FLAGS_INIT "-include $PROJ/scripts/maemo-compat.h -include $OBJ/compat/gdk-key-compat.h -O2")
set(CMAKE_FIND_ROOT_PATH $SR)
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
EOF
export PKG_CONFIG_LIBDIR="$SR/usr/lib/pkgconfig" PKG_CONFIG_SYSROOT_DIR="$SR"
# MAEMO_DEPS puts shim/include before the sysroot headers (see scripts/maemo-gcc)
export MAEMO_DEPS="$PROJ/apps/sgt-puzzles/shim"
cd "$OBJ"
cmake -G "Unix Makefiles" -DCMAKE_TOOLCHAIN_FILE="$OBJ/toolchain.cmake" -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/opt/sgt-puzzles -DPUZZLES_GTK_VERSION=2 -DNAME_PREFIX=sgt- \
    "$SRCDIR/sgt-puzzles-$VERSION" > "$OUT/configure.log" 2>&1 || { tail -30 "$OUT/configure.log"; exit 1; }
make -j"$(nproc)" > "$OUT/make.log" 2>&1 || { grep -E 'error|Error' "$OUT/make.log" | head -20; tail -15 "$OUT/make.log"; exit 1; }
make DESTDIR="$OUT/root" install > "$OUT/install.log" 2>&1 || { tail -15 "$OUT/install.log"; exit 1; }
ROOT="$OUT/root/opt/sgt-puzzles"
for b in "$ROOT"/bin/*; do arm-linux-gnueabi-strip --strip-unneeded "$b"; done
cp "$SRCDIR/sgt-puzzles-$VERSION/LICENCE" "$OUT/LICENCE"
# the list for the launcher: name|Title|description, from the .desktop files of the puzzles (then they are not needed: the menu has one entry, the launcher)
for d in "$ROOT"/share/applications/sgt-*.desktop; do
    n=$(basename "$d" .desktop); n=${n#sgt-}
    echo "$n|$(sed -n 's/^Name=//p' "$d")|$(sed -n 's/^Comment=//p' "$d")"
done | sort -t'|' -k2,2f > "$ROOT/share/puzzles.list"
rm -rf "$ROOT/share/applications"
# the launcher (GTK 2 + Hildon): a finger-sized list that starts the puzzles
"$PROJ/scripts/maemo-gcc" -O2 -Wall -include "$PROJ/scripts/maemo-compat.h" $(pkg-config --cflags gtk+-2.0 hildon-1) "$PROJ/apps/sgt-puzzles/puzzles-launcher.c" \
    -o "$OUT/puzzles.unstripped" $(pkg-config --libs gtk+-2.0 hildon-1)
arm-linux-gnueabi-strip -o "$ROOT/bin/puzzles" "$OUT/puzzles.unstripped"
echo "== Check"
echo "$(ls "$ROOT/bin" | grep -c "^sgt-") puzzles + the launcher: $(ls "$ROOT/bin" | sed 's/^sgt-//' | tr '\n' ' ')"
file "$ROOT/bin/sgt-net" | cut -c1-140
arm-linux-gnueabi-readelf -d "$ROOT/bin/sgt-net" | grep NEEDED
echo -n "Highest glibc symbol: "
arm-linux-gnueabi-objdump -T "$ROOT"/bin/* | grep -oE 'GLIBC_[0-9.]+' | sort -uV | tail -1
du -sh "$ROOT/bin"
