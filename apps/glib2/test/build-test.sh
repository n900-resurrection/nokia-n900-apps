#!/bin/bash
# Link test/glibtest.c statically against the GLib in build/deps and run it under qemu-user. Run INSIDE the Workshop.
set -euo pipefail
VERSION="${VERSION:-2.66.8}"
P=/project/build/deps/glib2-$VERSION
export PKG_CONFIG_PATH="$P/lib/pkgconfig:/project/build/deps/libffi-3.4.6/lib/pkgconfig:/project/build/deps/zlib-1.3.2/lib/pkgconfig"
export MAEMO_DEPS="$P:/project/build/deps/libffi-3.4.6:/project/build/deps/zlib-1.3.2"
OUT=/project/build/out/glib2-$VERSION; mkdir -p "$OUT"
/project/scripts/maemo-gcc -Os -include /project/scripts/maemo-compat.h -o "$OUT/glibtest" /project/apps/glib2/test/glibtest.c \
    $(pkg-config --cflags glib-2.0 gio-2.0) $(pkg-config --static --libs gio-2.0) -lpthread -lrt
arm-linux-gnueabi-strip "$OUT/glibtest"
echo "== max GLIBC symbol: $(arm-linux-gnueabi-objdump -T "$OUT/glibtest" | grep -o 'GLIBC_[0-9.]*' | sort -uV | tail -1); size $(stat -c %s "$OUT/glibtest")"
qemu-arm -L /project/sysroot "$OUT/glibtest"
