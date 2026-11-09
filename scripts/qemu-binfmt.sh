#!/bin/bash
# Make sure that the kernel runs ARM ELF files through the STATIC qemu-user (binfmt_misc entry "qemu-arm", flags O C F). Run INSIDE the Workshop (needs sudo).
# Why static: the chroot of the emulated phone (scripts/emu-test.sh) and the packages unpacked into ./sysroot (hildon-session.sh) run ARM programs
# whose root is not the root of the Workshop; the dynamic qemu-arm of Ubuntu would not find its x86 libraries there, and the flag F (the interpreter is
# opened when the entry is registered) lets the kernel use it from any root. The package qemu-user-static registers such an entry itself at boot; this
# script repairs the cases where there is none or it points to the dynamic binary (the Workshop was restarted, an older registration).
set -uo pipefail
B=/proc/sys/fs/binfmt_misc
Q=$(command -v qemu-arm-static) || { echo "qemu-binfmt: qemu-user-static is not installed (sudo apt install qemu-user-static)" >&2; exit 1; }
[ -e $B/register ] || sudo mount -t binfmt_misc binfmt_misc $B 2>/dev/null || { echo "qemu-binfmt: binfmt_misc cannot be mounted" >&2; exit 1; }
if [ -e $B/qemu-arm ]; then
    if grep -q '^interpreter .*\(qemu-arm-static\|arm-binfmt-P\)' $B/qemu-arm && grep -q '^flags: .*F' $B/qemu-arm; then exit 0; fi
    echo -1 | sudo tee $B/qemu-arm >/dev/null
fi
printf ':qemu-arm:M::\\x7fELF\\x01\\x01\\x01\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x02\\x00\\x28\\x00:\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\x00\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xfe\\xff\\xff\\xff:%s:OCF\n' "$Q" \
    | sudo tee $B/register >/dev/null
