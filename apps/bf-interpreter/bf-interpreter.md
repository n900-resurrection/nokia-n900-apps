# bf-interpreter 0.1 on Maemo 5

Status 2026-11-17. Build and packaging: [Makefile](Makefile) (`make bf-interpreter`, `make -C apps/bf-interpreter <target>`); conventions in [../../mk/app.mk](../../mk/app.mk).

A small Brainfuck interpreter in C (one file, no dependencies besides libc). It is our own project: <https://github.com/elPytel/BF_interpreter> (MIT). The package installs the command `bf`:

```sh
bf /opt/bf-interpreter/share/examples/hello_world.bf     # prints "Hello World!"
```

## Build

- `build.sh` clones the upstream repository and checks out the pinned commit (`COMMIT`, now `c9ad0e8`; the project has no tags). It compiles `bf.c` with `scripts/maemo-gcc` and strips it
  (6 kB). The upstream Makefile is not used: it wants `clang` and `-lm`, which the code does not need.
- `NEEDED`: libc.so.6 only; the highest symbol is `GLIBC_2.4`.
- Raise `COMMIT` when the interpreter changes, and `REV` of the package with it.

## Package `bf-interpreter`

- `Depends: libc6 (>= 2.5)`, `Section: user/development`, 7 kB.
- Files: `/opt/bf-interpreter/bin/bf`, a link `/usr/bin/bf`, `LICENSE`, `README.md`, the example `/opt/bf-interpreter/share/examples/hello_world.bf`.
- No menu entry: the program needs a file argument and `osso-xterm -e` with arguments is not verified. The icon is only for the Application Manager list and the web catalogue (`make-icon.sh` draws `[+> .<]`).

## Verified

- Cross-build, `.deb` (metadata, contents).
- On the test phone: installation with `dpkg -i`, `make -C apps/bf-interpreter test` (6 tests: package, usage, link, example, "Hello World!", no missing libraries).

## Known behaviour of the upstream code

- `char` is **unsigned** on ARM (signed on x86): the cells wrap at 256 in both cases, but a program that tests the cell for a negative value or reads end of file (`getchar` returns `-1`) can behave differently from the x86 build.
- The tape grows to the right on demand; moving left of the first cell ends the program with `FATAL: Tape index out of bounds!`.
