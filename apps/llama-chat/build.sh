#!/bin/bash
# Pure Python: the syntax of the scripts and the tests of the logic (fake engine, file:// downloads; needs curl).
set -euo pipefail
cd /project/apps/llama-chat
for f in llama_chat.py llama-chat ../llama2c/tools/st2llama2c.py tests/test_llama_chat.py; do
    python3 -I -c "import ast,sys; ast.parse(open('$f').read())"
done
python3 -I tests/test_llama_chat.py > /tmp/llama-chat-test.log 2>&1 || { cat /tmp/llama-chat-test.log; exit 1; }
echo "llama-chat: syntax ok, $(grep -o 'Ran [0-9]* tests' /tmp/llama-chat-test.log) passed"
