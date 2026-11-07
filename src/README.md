# src: source code for the N900

Test programs, one directory per language: [c/hello](c/hello/hello.c) (this page), [go/hello](go/hello), [python3/hello](python3/hello) and
[rust/hello](rust/hello); `python3/hildon` is a GTK/Hildon proof for the emulator. The C program [hello.c](c/hello/hello.c) is a test for
Maemo 5 (armel, glibc 2.5). Verified 2026-11-04: built in the Workshop and run on a real N900.

## Prerequisites (once)

Once, from the project folder (`/home/pytel/Git/N900`):

```bash
make up          # create and start the Workshop "n900" (first run)
make toolchain   # cross gcc (armel) and qemu-user
make sysroot     # the Fremantle SDK sysroot into ./sysroot
```

The N900 must run an SSH server and `~/.ssh/config` on the computer must have the alias `n900`
(see [../.env](../.env), `DEVICE=n900`). How to get access is described in [../DOC/workshop-crosscompile.md](../DOC/workshop-crosscompile.md)
and in the SSH notes.

## 1. Build

The wrapper [../scripts/maemo-gcc](../scripts/maemo-gcc) compiles inside the Workshop:

```bash
workshop exec n900 -- bash -c 'cd /project && mkdir -p build && scripts/maemo-gcc -O2 -o build/hello src/c/hello/hello.c'
```

The shortcut that also runs the binary under qemu against the sysroot with glibc 2.5:

```bash
make hello
```

The result is `build/hello` (ELF 32-bit ARM, EABI5). Check that it needs only old glibc symbols:

```bash
workshop exec n900 -- bash -c 'cd /project && arm-linux-gnueabi-objdump -T build/hello | grep GLIBC'
```

The highest symbol should be `GLIBC_2.4`. A newer one will not run on Maemo 5.

## 2. Copy to the N900

```bash
make push
```

This runs `scp build/hello n900:/home/user/apps/` (the values `DEVICE`, `FILE` and `DEST` are in `.env` and `.env.default`).
Another file or destination:

```bash
make push FILE=build/other DEST=/home/user/bin/
```

**Do not copy into `/home/user/MyDocs`.** It is a FAT partition mounted `noexec`; running a program there ends with `Permission denied`.

## 3. Run remotely

```bash
ssh n900 /home/user/apps/hello
```

Expected output:

```
Hello from Maemo 5 (armel, glibc 2.5)
```

If the binary is not executable: `ssh n900 chmod +x /home/user/apps/hello`.
`make push` creates the destination folder itself (`ssh n900 mkdir -p ...`).

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `no matching host key type found` | SSH goes to the IP instead of the alias. Use `n900` (the alias in `~/.ssh/config` with `HostKeyAlgorithms +ssh-rsa`). |
| `Permission denied` when running | The binary is in `MyDocs` (noexec) or lacks the execute permission. |
| `GLIBC_2.xx not found` | Built without `maemo-gcc`, or the code needs a newer glibc than 2.5. |
| `No route to host` / timeout | The phone is not on Wi-Fi or has another IP. |
| `make push` says "Set DEVICE" | Add `DEVICE=n900` to `.env`. |
