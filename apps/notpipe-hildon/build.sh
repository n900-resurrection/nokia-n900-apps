#!/bin/bash
# Pure Python: the syntax of the scripts and the tests of the logic (a fake Invidious server on localhost, fake player and ffmpeg; needs curl).
set -euo pipefail
cd /project/apps/notpipe-hildon
for f in notpipe_core.py notpipe-hildon tests/test_notpipe_core.py; do
    python3 -I -c "import ast,sys; ast.parse(open('$f').read())"
done
python3 -I -W ignore tests/test_notpipe_core.py > /tmp/notpipe-test.log 2>&1 || { cat /tmp/notpipe-test.log; exit 1; }
echo "notpipe-hildon: syntax ok, $(grep -o 'Ran [0-9]* tests' /tmp/notpipe-test.log) passed"
