#!/bin/bash
# ntp-sync is a shell script, nothing to compile. Check the syntax only.
set -euo pipefail
cd "$(dirname "$0")"
sh -n ntp-sync && sh -n ntp-sync.hook && echo "ntp-sync: syntax OK"
