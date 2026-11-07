#!/bin/bash
# Copy the screenshots of the phone (Fremantle saves them to MyDocs/.images/Screenshots) into ./screenshots on the host.
# Only files that are not there yet are copied. Usage: scripts/screenshots.sh <DEVICE> [DEST]   (make screenshots)
set -euo pipefail
DEVICE="${1:?Set DEVICE (ssh alias or user@host)}"
DEST="${2:-$(dirname "$0")/../screenshots}"
SRC=/home/user/MyDocs/.images/Screenshots
mkdir -p "$DEST"
n=0
for f in $(ssh -q "$DEVICE" "ls $SRC 2>/dev/null"); do
    [ -e "$DEST/$f" ] && continue
    scp -q -p "$DEVICE:$SRC/$f" "$DEST/$f" && { echo "$f"; n=$((n+1)); }
done
echo "$n new screenshot(s) in $DEST"
