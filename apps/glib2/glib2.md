# GLib 2.66 (static build dependency)

The phone has GLib 2.20, which Hildon runs on. Programs that need a newer one (irssi, mc, ...) link this copy **statically**, so the system library stays untouched. It is a build dependency, not a package
(like [openssl](../openssl/build.sh)): `make -C apps/glib2 build` creates `build/deps/glib2-2.66.8/{include,lib}` with `libglib`, `libgobject`, `libgmodule`, `libgthread` and `libgio` (`.a`).

Use it from another app's `build.sh`:

```sh
P=/project/build/deps/glib2-2.66.8
export PKG_CONFIG_PATH="$P/lib/pkgconfig:/project/build/deps/libffi-3.4.6/lib/pkgconfig:/project/build/deps/zlib-1.3.2/lib/pkgconfig"
export MAEMO_DEPS="$P:/project/build/deps/libffi-3.4.6:/project/build/deps/zlib-1.3.2"
# link: $(pkg-config --static --libs glib-2.0 gio-2.0) -lpthread -lrt
```

## How it is built ([build.sh](build.sh))

- Meson (installed in the Workshop, `meson` is in [.workshop/n900.yaml](../../.workshop/n900.yaml)) with a generated cross file: `scripts/maemo-gcc`, `qemu-arm -L sysroot` as the exe wrapper.
- Options: static, bundled PCRE (`internal_pcre`), no libmount, SELinux, xattr, NLS, man pages and tests. libffi and zlib come from `build/deps` (built by `apps/python3`).
- Two patches of `meson.build`, applied by the script: the C++ language is dropped (the only check that uses it, ISO varargs macros in C++, is answered `true`) and the `tests` and `fuzzing` subdirectories are skipped (they need C++, dbus and libelf).
- No source patches and no extra shims were needed: the Maemo glibc 2.5 has `eventfd` (as `GLIBC_2.7`), `splice` and `O_CLOEXEC` works through [maemo-compat.h](../../scripts/maemo-compat.h).
- 2.66.8 is the last 2.66 release. Newer series (2.68+) need more of the toolchain (the C++ and Python tools, newer meson) and were not tried.

## Test

`apps/glib2/test/build-test.sh` links [glibtest.c](test/glibtest.c) against the static GLib and runs it under qemu. The program checks hash tables, regex (bundled PCRE), `GKeyFile`, UUID, `GDateTime`, UTF-8, file functions, `GFile`/`GFileInfo`, the main loop, `GInetAddress` and threads.
Result (2026-11-11): ALL OK under qemu-user and on the phone (kernel 2.6.28, binary 2.4 MB, needs only `GLIBC_2.7`).

## Next

irssi (needs GLib >= 2.32), mc (>= 2.30), possibly WeeChat and profanity: see [TODO.md](../../TODO.md).
