#!/bin/bash
# apt-transport-curl is a shell script, nothing to compile. Check the syntax only.
set -euo pipefail
cd "$(dirname "$0")"
bash -n https && echo "apt-transport-curl: syntax OK"
