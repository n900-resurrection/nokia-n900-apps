#!/bin/bash
# Pure Python: only check the syntax.
set -euo pipefail
python3 -I -c "import ast,sys; ast.parse(open('/project/apps/selfie/selfie').read())"
echo "selfie: syntax ok"
