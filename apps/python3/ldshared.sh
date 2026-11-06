#!/bin/sh
# Linker for the shared Python extension modules (LDSHARED=ldshared.sh -shared, see build.sh).
# Python's setup.py does not know the private static libraries, so for readline (history + terminal functions from
# ncursesw) and _ctypes (libffi) the libraries are appended AFTER the objects (static archive order). Unused archive
# members are not pulled in, so the other modules are not affected.
exec /project/scripts/maemo-gcc "$@" \
    -L/project/build/deps/libffi-3.4.6/lib -lffi \
    -L/project/build/deps/readline-8.2/lib -lhistory \
    -L/project/build/deps/ncursesw-static/lib -lncursesw
