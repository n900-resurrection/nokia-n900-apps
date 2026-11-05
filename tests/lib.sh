# Helpers for the on-device tests (POSIX sh, runs in the busybox ash of the N900 and in bash).
# Usage: make test (all apps) or make -C apps/<app> test. The Makefile sends this file and
# apps/<app>/test.sh to the phone through one ssh session:  cat lib.sh test.sh | ssh n900 sh -s
# Do not execute this file by itself.
PASS=0
FAIL=0
SKIP=0

# t <name> <expected output> <command...>   ... compares stdout+stderr of the command (trailing newlines ignored)
t() {
    _n=$1; _exp=$2; shift 2
    _got=$("$@" 2>&1)
    if [ "$_got" = "$_exp" ]; then
        PASS=$((PASS + 1)); printf 'ok    %s\n' "$_n"
    else
        FAIL=$((FAIL + 1)); printf 'FAIL  %s\n      expected: %s\n      got:      %s\n' "$_n" "$_exp" "$_got"
    fi
}

# ok <name> <command...>   ... passes when the command exits with 0 (output is hidden)
ok() {
    _n=$1; shift
    if "$@" >/dev/null 2>&1; then
        PASS=$((PASS + 1)); printf 'ok    %s\n' "$_n"
    else
        FAIL=$((FAIL + 1)); printf 'FAIL  %s: %s\n' "$_n" "$*"
    fi
}

# contains <name> <text> <command...>   ... passes when the output of the command contains the text
contains() {
    _n=$1; _txt=$2; shift 2
    _got=$("$@" 2>&1)
    case $_got in
        *"$_txt"*) PASS=$((PASS + 1)); printf 'ok    %s\n' "$_n" ;;
        *) FAIL=$((FAIL + 1)); printf 'FAIL  %s\n      wanted text: %s\n      got:         %s\n' "$_n" "$_txt" "$_got" ;;
    esac
}

# need_pkg <package>   ... fails when the package is not installed; call it first in a test.sh
need_pkg() {
    if dpkg -s "$1" 2>/dev/null | grep -q '^Status: install ok installed'; then
        PASS=$((PASS + 1)); printf 'ok    package %s installed\n' "$1"
    else
        FAIL=$((FAIL + 1)); printf 'FAIL  package %s is not installed (make -C apps/<app> install)\n' "$1"
    fi
}

# skip <name> <reason>
skip() { SKIP=$((SKIP + 1)); printf 'skip  %s (%s)\n' "$1" "$2"; }

# tmpdir: go to a fresh temporary directory (removed by summary). Not /tmp: it is a 1 MB tmpfs on the N900.
TESTDIR=
tmpdir() { TESTDIR=$(mktemp -d /home/user/.n900test.XXXXXX) && cd "$TESTDIR"; }

# summary   ... prints the totals; the exit status is 1 when something failed
summary() {
    cd /
    if [ -n "$TESTDIR" ]; then rm -r "$TESTDIR"; fi
    printf '\n%s: %d passed, %d failed, %d skipped\n' "${TEST_NAME:-tests}" "$PASS" "$FAIL" "$SKIP"
    [ "$FAIL" -eq 0 ]
}
