#!/bin/bash
# Cross-build jq (JSON processor) for Maemo 5 (armel, glibc 2.5). Run INSIDE the Workshop:
#   workshop exec n900 -- bash -c 'VERSION=1.8.2 /project/apps/jq/build.sh'   (or: make -C apps/jq build)
# Output: /project/build/out/jq-$VERSION/jq   (stripped binary)
# The oniguruma regex library is bundled in the release tarball and linked statically.
set -euo pipefail

VERSION="${VERSION:-1.8.2}"
PROJ=/project
SR="$PROJ/sysroot"
DL="$PROJ/build/downloads"
SRCDIR="$PROJ/build/src"
OUT="$PROJ/build/out/jq-$VERSION"
OBJ="$PROJ/build/obj/jq-$VERSION"

[ -d "$SR/usr/include" ] || { echo "Missing sysroot, run: make sysroot"; exit 1; }
mkdir -p "$DL" "$SRCDIR"
f="jq-$VERSION.tar.gz"
[ -s "$DL/$f" ] || curl -fL --retry 3 -o "$DL/$f" "https://github.com/jqlang/jq/releases/download/jq-$VERSION/$f"
echo "sha256 $(sha256sum "$DL/$f" | cut -d' ' -f1)  $f"
rm -rf "$SRCDIR/jq-$VERSION" "$OBJ" "$OUT"
tar -C "$SRCDIR" -xzf "$DL/$f"
mkdir -p "$OBJ" "$OUT/root"
cd "$OBJ"

# - --disable-docs: the manual needs ruby/pipenv.
# - --with-oniguruma=builtin: use the bundled copy (the device has none).
# - --disable-maintainer-mode: do not re-run autotools.
# - O_CLOEXEC etc.: scripts/maemo-compat.h (glibc 2.5 headers lack them).
"$SRCDIR/jq-$VERSION/configure" \
    --host=arm-linux-gnueabi --build="$(gcc -dumpmachine)" \
    --prefix=/opt/jq \
    --disable-docs --disable-maintainer-mode --with-oniguruma=builtin --disable-shared --enable-static \
    CC="$PROJ/scripts/maemo-gcc" \
    CFLAGS="-Os -include $PROJ/scripts/maemo-compat.h" \
    > "$OUT/configure.log" 2>&1 || { tail -30 "$OUT/configure.log"; exit 1; }
make -j"$(nproc)" > "$OUT/make.log" 2>&1 || { grep -E 'error|Error' "$OUT/make.log" | head -20; exit 1; }
arm-linux-gnueabi-strip -o "$OUT/jq" jq

echo "== Check"
file "$OUT/jq" | cut -c1-140
ls -l "$OUT/jq"
