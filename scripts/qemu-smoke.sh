#!/bin/bash
# Smoke tests of the built programs under qemu-user, without the phone. Run INSIDE the Workshop:
#   make qemu-smoke                  (all programs listed below; a program that is not built is skipped)
#   make qemu-smoke APP="jq rsync"   (some of them)
# Every check runs through scripts/qemu-n900: kernel 2.6.28 reported, one CPU, a 1 MB /tmp, glibc 2.5 of the sysroot.
# These are not the tests of the phone (apps/<app>/test.sh): they cannot see the packaging or the device libraries, but they catch a program that
# does not start, a wrong symbol or a broken feature right after the build, and they need no phone and no network.
set -uo pipefail
. "$(dirname "$0")/qemu-lib.sh"
WANT=" ${APPS:-} "
want() { [ "$WANT" = "  " ] || case "$WANT" in *" $1 "*) return 0 ;; *) return 1 ;; esac; }
T=$(scratch); trap 'rm -rf "$T"' EXIT

if want jq; then
    B=$(bin jq-1.8.2/jq) || true
    if [ -n "${B:-}" ]; then
        has jq-version "jq-1.8" run "$B" --version
        has jq-filter "3" sh -c "echo '{\"a\":[1,2]}' | $PROJ/scripts/qemu-n900 $B '.a|add'"
    else skip jq "not built: make jq"; fi
fi

if want ripgrep; then
    B=$(bin ripgrep-15.2.0/rg) || true
    if [ -n "${B:-}" ]; then
        printf 'alpha\nbeta\ngamma\n' > "$T/f.txt"
        has rg-version "ripgrep 15" run "$B" --version
        has rg-search "beta" run "$B" beta "$T/f.txt"
    else skip ripgrep "not built"; fi
fi

if want fd; then
    B=$(bin fd-find-10.5.2/fd) || true
    if [ -n "${B:-}" ]; then
        mkdir -p "$T/d/sub"; : > "$T/d/sub/needle.txt"
        has fd-version "fd 10" run "$B" --version
        has fd-find "needle.txt" run "$B" needle "$T/d"
    else skip fd "not built"; fi
fi

if want fzf; then
    B=$(bin fzf-0.75.0/fzf) || true
    if [ -n "${B:-}" ]; then
        has fzf-version "0.75" run "$B" --version
        has fzf-filter "beta" sh -c "printf 'alpha\nbeta\n' | $PROJ/scripts/qemu-n900 $B -f beta"
    else skip fzf "not built"; fi
fi

if want age; then
    B=$(bin age-1.2.1/age) || true; K=$(bin age-keygen-1.2.1/age-keygen) || true
    if [ -n "${B:-}" ] && [ -n "${K:-}" ]; then
        has age-version "1.2.1" run "$B" --version
        run "$K" -o "$T/key.txt" >/dev/null 2>&1
        pub=$(run "$K" -y "$T/key.txt" 2>/dev/null)
        printf 'secret message' > "$T/m.txt"
        check age-encrypt sh -c "$PROJ/scripts/qemu-n900 $B -r $pub -o $T/m.age $T/m.txt"
        has age-roundtrip "secret message" run "$B" -d -i "$T/key.txt" "$T/m.age"
    else skip age "not built"; fi
fi

if want rsync; then
    B=$(bin rsync-3.5.2/root/opt/rsync/bin/rsync) || true
    if [ -n "${B:-}" ]; then
        mkdir -p "$T/src/a" "$T/dst"; echo data > "$T/src/a/f.txt"
        has rsync-version "version 3.5" run "$B" --version
        # the receiver process of a local copy fails in chdir() under qemu-user (change_dir "No such file or directory", even with --no-limits);
        # the same copy passes on the phone (apps/rsync/test.sh copy-tree). Not a fault of the package: tested on the phone only.
        skip rsync-copy "local transfer does not work under qemu-user, see apps/rsync/test.sh"
    else skip rsync "not built"; fi
fi

if want ncdu; then
    B=$(bin ncdu-1.22/root/opt/ncdu/bin/ncdu) || true
    if [ -n "${B:-}" ]; then
        mkdir -p "$T/n"; head -c 1000 /dev/zero > "$T/n/big.bin"
        has ncdu-version "ncdu 1.22" run "$B" -v
        has ncdu-export "big.bin" run "$B" -o - "$T/n"
    else skip ncdu "not built"; fi
fi

if want htop; then
    B=$(bin htop-3.5.3/root/opt/htop3/bin/htop) || true
    if [ -n "${B:-}" ]; then
        has htop-version "htop 3.5" run "$B" --version
    else skip htop "not built"; fi
fi

if want strace; then
    B=$(bin strace-6.19/root/opt/strace/bin/strace) || true
    if [ -n "${B:-}" ]; then
        has strace-version "6.19" run "$B" -V
        skip strace-trace "ptrace of a qemu guest is not possible"
    else skip strace "not built"; fi
fi

if want file; then
    B=$(bin file-5.48/root/opt/file/bin/file) || true
    if [ -n "${B:-}" ]; then
        has file-version "file-5.48" run "$B" --version
    else skip file "not built"; fi
fi

if want tig; then
    B=$(bin tig-2.6.1/root/opt/tig/bin/tig) || true
    if [ -n "${B:-}" ]; then has tig-version "tig version 2.6" run "$B" --version; else skip tig "not built"; fi
fi

if want links; then
    B=$(bin links-2.30/root/opt/links/bin/links) || true
    if [ -n "${B:-}" ]; then
        printf '<html><body><h1>Hello N900</h1><p>text mode</p></body></html>' > "$T/p.html"
        has links-version "Links 2.30" run "$B" -version
        has links-dump "Hello N900" run "$B" -dump "$T/p.html"
    else skip links "not built"; fi
fi

if want dialog; then
    B=$(bin dialog-1.3-20260721/root/opt/dialog/bin/dialog) || true
    if [ -n "${B:-}" ]; then has dialog-version "Version: 1.3" run "$B" --version; else skip dialog "not built"; fi
fi

qsummary "qemu smoke"
