#!/bin/bash
# Cross-build WeeChat for Maemo 5 (armel, glibc 2.5). Run INSIDE the Workshop: make -C apps/weechat build
# Output: /project/build/out/weechat-$VERSION/{weechat, root/}
# Links statically: GnuTLS + libgcrypt (apps/gnutls), libcurl with mbedTLS (apps/curl) and ncursesw of the sysroot (UTF-8). Only the plugins that make
# sense on the phone are built: no Perl, Python, Ruby, Lua, Tcl, Guile or PHP scripting, no relay, no spell checker, no NLS, no cJSON and no zstd.
set -euo pipefail

VERSION="${VERSION:-4.10.4}"
PROJ=/project
SR="$PROJ/sysroot"
DL="$PROJ/build/downloads"
SRCDIR="$PROJ/build/src"
OUT="$PROJ/build/out/weechat-$VERSION"
OBJ="$PROJ/build/obj/weechat-$VERSION"
TLS="$PROJ/build/deps/gnutls-3.8.13"
CURL="$PROJ/build/out/curl-8.23.0/root/opt/curl"
MBED="$PROJ/build/deps/mbedtls-3.6.7/usr/local"

[ -d "$SR/usr/include" ] || { echo "Missing sysroot, run: make sysroot"; exit 1; }
[ -f "$TLS/lib/libgnutls.a" ] || { echo "Missing GnuTLS, run: make -C apps/gnutls build"; exit 1; }
[ -f "$CURL/lib/libcurl.a" ] || { echo "Missing libcurl, run: make -C apps/curl build"; exit 1; }
mkdir -p "$DL" "$SRCDIR"
f="weechat-$VERSION.tar.xz"
[ -s "$DL/$f" ] || curl -fL --retry 3 -o "$DL/$f" "https://weechat.org/files/src/$f"
echo "sha256 $(sha256sum "$DL/$f" | cut -d' ' -f1)  $f"
rm -rf "$SRCDIR/weechat-$VERSION" "$OBJ" "$OUT"
tar -C "$SRCDIR" -xJf "$DL/$f"
mkdir -p "$OBJ/pc" "$OUT/root"

# libcurl.pc of the curl build points to /opt/curl (the target path): a copy with the real paths, and the static mbedTLS libraries.
sed -e "s|^prefix=.*|prefix=$CURL|" -e "s|-L/project/build/deps/mbedtls-3.6.7/usr/local/lib|-L$MBED/lib|g" -e "s|^Libs:.*|Libs: -L\${libdir} -lcurl -L$MBED/lib -lmbedtls -lmbedx509 -lmbedcrypto -lz -lrt -pthread|" \
    "$CURL/lib/pkgconfig/libcurl.pc" > "$OBJ/pc/libcurl.pc"
export PKG_CONFIG_PATH="$OBJ/pc:$TLS/lib/pkgconfig:$PROJ/build/deps/zlib-1.3.2/lib/pkgconfig"
export MAEMO_DEPS="$TLS:$CURL:$MBED"

cat > "$OBJ/toolchain.cmake" <<TC
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR arm)
set(CMAKE_C_COMPILER $PROJ/scripts/maemo-gcc)
set(CMAKE_FIND_ROOT_PATH $SR $TLS $CURL)
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
TC

# libcurl.a was built against zlib 1.3.2 (inflateReset2 needs >= 1.2.4), the sysroot and the phone have 1.2.3: the executable takes inflate from the static
# libz.a of 1.3.2 (-u forces it to be pulled in before the objects); the plugin modules do not use zlib.
# libatomic: gnutls.pc asks for it, the sysroot has none and the 64-bit atomics of ARMv7 are inline: an empty archive satisfies the linker.
[ -f "$OBJ/stub/libatomic.a" ] || { mkdir -p "$OBJ/stub"; arm-linux-gnueabi-ar rc "$OBJ/stub/libatomic.a"; }

cd "$OBJ"
cmake -G Ninja "$SRCDIR/weechat-$VERSION" -DCMAKE_TOOLCHAIN_FILE="$OBJ/toolchain.cmake" -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/opt/weechat -DCMAKE_C_FLAGS="-Os -include $PROJ/scripts/maemo-compat.h -include $PROJ/scripts/maemo-endian.h" \
    -DNCURSES_INCLUDE_PATH="$SR/usr/include/ncursesw" -DNCURSESW_LIBRARY="$SR/usr/lib/libncursesw.a" -DNCURSES_LIBRARY="$SR/usr/lib/libncursesw.a" \
    -DCMAKE_EXE_LINKER_FLAGS="-L$OBJ/stub -L$TLS/lib -Wl,-u,inflateReset2 $PROJ/build/deps/zlib-1.3.2/lib/libz.a" -DCMAKE_MODULE_LINKER_FLAGS="-L$OBJ/stub -L$TLS/lib" -DCMAKE_SHARED_LINKER_FLAGS="-L$OBJ/stub -L$TLS/lib" \
    -DCMAKE_C_STANDARD_LIBRARIES="-lgnutls -lhogweed -lnettle -lgmp -ltasn1 -lgcrypt -lgpg-error -lz -ldl -lpthread" \
    -DENABLE_NLS=OFF -DENABLE_ZSTD=OFF -DENABLE_CJSON=OFF -DENABLE_HEADLESS=OFF -DENABLE_RELAY=OFF -DENABLE_SCRIPT=OFF -DENABLE_SCRIPTS=OFF \
    -DENABLE_PERL=OFF -DENABLE_PYTHON=OFF -DENABLE_RUBY=OFF -DENABLE_LUA=OFF -DENABLE_TCL=OFF -DENABLE_GUILE=OFF -DENABLE_PHP=OFF -DENABLE_JAVASCRIPT=OFF \
    -DENABLE_SPELL=OFF -DENABLE_MAN=OFF -DENABLE_DOC=OFF -DENABLE_TESTS=OFF \
    > "$OUT/cmake.log" 2>&1 || { tail -40 "$OUT/cmake.log"; exit 1; }
ninja > "$OUT/ninja.log" 2>&1 || { grep -E "error|FAILED" "$OUT/ninja.log" | head -20; tail -8 "$OUT/ninja.log"; exit 1; }
DESTDIR="$OUT/root" ninja install > "$OUT/install.log" 2>&1 || { tail -20 "$OUT/install.log"; exit 1; }
arm-linux-gnueabi-strip -o "$OUT/weechat" "$OUT/root/opt/weechat/bin/weechat"
cp "$SRCDIR/weechat-$VERSION/COPYING" "$OUT/COPYING"
echo "== Check"
file "$OUT/weechat" | cut -c1-140
arm-linux-gnueabi-readelf -d "$OUT/weechat" | grep NEEDED
echo -n "Highest glibc symbol: "
arm-linux-gnueabi-objdump -T "$OUT/weechat" | grep -oE 'GLIBC_[0-9.]+' | sort -uV | tail -1
ls -l "$OUT/weechat"
find "$OUT/root/opt/weechat" -name "*.so" | head -20
