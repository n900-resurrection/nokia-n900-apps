#!/bin/bash
# Cross-build Brogue CE (Community Edition of the roguelike Brogue) for Maemo 5 (armel, glibc 2.5). Run INSIDE the Workshop:
#   workshop exec n900 -- bash -c 'VERSION=1.14.1 /project/apps/brogue-ce/build.sh'   (or: make -C apps/brogue-ce build)
# Output: /project/build/out/brogue-ce-$VERSION/root/opt/brogue-ce/{bin/brogue,share/assets,share/keymap.txt}
#
# One binary with both interfaces: the graphical one (SDL 2 + SDL2_image, tiles; run with --no-gpu, the phone has no OpenGL) and the terminal one (--term,
# ncurses). It links the shared SDL 2 libraries of apps/sdl2 and apps/sdl2-image (/opt/sdl2/lib, rpath) and the libncurses.so.5 of the phone.
# The sources are not changed. The game data is searched in DATADIR=/opt/brogue-ce/share (assets/tiles.png, keymap.txt).
set -euo pipefail

VERSION="${VERSION:-1.14.1}"
PROJ=/project
SR="$PROJ/sysroot"
DL="$PROJ/build/downloads"
SRCDIR="$PROJ/build/src"
OUT="$PROJ/build/out/brogue-ce-$VERSION"
. "$PROJ/apps/sdl2/sdl2-env.sh"
IMGOUT="$PROJ/build/out/sdl2-image-${SDL2_IMAGE_VERSION:-2.8.8}/root/opt/sdl2"
[ -f "$IMGOUT/lib/libSDL2_image.so" ] || { echo "Missing SDL2_image ($IMGOUT), run: make sdl2-image"; exit 1; }

mkdir -p "$DL" "$SRCDIR"
f="BrogueCE-$VERSION.tar.gz"
[ -s "$DL/$f" ] || curl -fL --retry 3 -o "$DL/$f" "https://github.com/tmewett/BrogueCE/archive/refs/tags/v$VERSION.tar.gz"
echo "sha256 $(sha256sum "$DL/$f" | cut -d' ' -f1)  $f"
rm -rf "$SRCDIR/BrogueCE-$VERSION" "$OUT"
tar -C "$SRCDIR" -xzf "$DL/$f"
mkdir -p "$OUT/root/opt/brogue-ce/bin" "$OUT/root/opt/brogue-ce/share"
cd "$SRCDIR/BrogueCE-$VERSION"

# sdl2-config of the cross build (the installed one names /opt/sdl2 of the phone)
cat > "$OUT/sdl2-config" <<EOF
#!/bin/sh
case "\$1" in
    --cflags) echo "-I$SDLROOT/include/SDL2 -D_REENTRANT" ;;
    --libs) echo "-L$SDLROOT/lib -L$IMGOUT/lib -Wl,-rpath,/opt/sdl2/lib -lSDL2" ;;
esac
EOF
chmod +x "$OUT/sdl2-config"

CC="$PROJ/scripts/maemo-gcc"
make -j"$(nproc)" bin/brogue TERMINAL=YES GRAPHICS=YES RELEASE=YES SDL_CONFIG="$OUT/sdl2-config" DATADIR=/opt/brogue-ce/share CC="$CC" \
    CFLAGS="-include $PROJ/scripts/maemo-compat.h -I$SR/usr/include/ncurses -I$IMGOUT/include/SDL2" LDLIBS="-L$IMGOUT/lib -Wl,-rpath,/opt/sdl2/lib" \
    > "$OUT/make.log" 2>&1 || { grep -E 'error|Error' "$OUT/make.log" | head -20; tail -15 "$OUT/make.log"; exit 1; }
ROOT="$OUT/root/opt/brogue-ce"
arm-linux-gnueabi-strip -o "$ROOT/bin/brogue" bin/brogue
cp -r bin/assets bin/keymap.txt "$ROOT/share/"
cp LICENSE.txt CHANGELOG.md "$OUT/"
echo "== Check"
file "$ROOT/bin/brogue" | cut -c1-140
arm-linux-gnueabi-readelf -d "$ROOT/bin/brogue" | grep -E "NEEDED|RPATH|RUNPATH"
echo -n "Highest glibc symbol: "
arm-linux-gnueabi-objdump -T "$ROOT/bin/brogue" | grep -oE 'GLIBC_[0-9.]+' | sort -uV | tail -1
ls -l "$ROOT/bin/brogue"; du -sh "$ROOT/share"
