# Helpers for the emulation tests that run under qemu-user in the Workshop (no phone needed). Source it, do not run it:
#   . /project/scripts/qemu-lib.sh
# The programs run through scripts/qemu-n900 (kernel 2.6.28 reported, one CPU, 1 MB /tmp, glibc 2.5 of the sysroot).
PROJ="${PROJ:-/project}"
OUT="$PROJ/build/out"
QPASS=0 QFAIL=0 QSKIP=0

# run PROGRAM [ARGS...]   ... the program under qemu with the phone-like limits (add --no-limits as the first argument to switch them off)
run() { "$PROJ/scripts/qemu-n900" "$@"; }

# check <name> <command...>   ... passes when the command exits with 0 (output hidden)
check() {
    local n=$1; shift
    if "$@" >/dev/null 2>&1; then QPASS=$((QPASS+1)); printf 'ok    %s\n' "$n"; else QFAIL=$((QFAIL+1)); printf 'FAIL  %s\n' "$n"; fi
}
# has <name> <text> <command...>   ... passes when the output of the command contains the text (shown on failure)
has() {
    local n=$1 want=$2; shift 2
    local got; got=$("$@" 2>&1)
    if printf '%s' "$got" | grep -qF -- "$want"; then QPASS=$((QPASS+1)); printf 'ok    %s\n' "$n"
    else QFAIL=$((QFAIL+1)); printf 'FAIL  %s\n      wanted: %s\n      got:    %s\n' "$n" "$want" "$(printf '%s' "$got" | head -c 200)"; fi
}
skip() { QSKIP=$((QSKIP+1)); printf 'skip  %s (%s)\n' "$1" "$2"; }
# bin <build/out relative path>   ... prints the absolute path when the program is built, else nothing
bin() { [ -x "$OUT/$1" ] && printf '%s' "$OUT/$1"; }
# a scratch directory in build/ (the /tmp of the emulation is a private 1 MB tmpfs: files of the harness would not be seen)
scratch() { mkdir -p "$PROJ/build/qscratch"; mktemp -d "$PROJ/build/qscratch/t.XXXXXX"; }
qsummary() { printf '\n%s: %d passed, %d failed, %d skipped\n' "${1:-emulation}" "$QPASS" "$QFAIL" "$QSKIP"; [ "$QFAIL" -eq 0 ]; }
