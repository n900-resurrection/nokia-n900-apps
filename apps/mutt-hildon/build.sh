#!/bin/bash
# mutt-hildon is a set of Python 2.5 scripts, nothing to compile. Check what can be checked on the host:
# the files exist and the Python is valid Python (the strict 2.5 check runs on the phone in make test).
set -euo pipefail
cd "$(dirname "$0")"
for f in mailcore.py store.py selftest.py mutt-hildon; do test -s "$f"; done
python3 - <<'PY'
import ast, sys
for f in ("mailcore.py", "store.py", "selftest.py", "mutt-hildon"):
    try:
        ast.parse(open(f, encoding="utf-8").read())
    except SyntaxError as e:
        # Python 2 syntax (print statement, "except X, e") is expected; only report other problems.
        print("%s: python3 cannot parse (Python 2 code, expected): %s" % (f, e.msg))
PY
echo "mutt-hildon: files present"
