#!/bin/sh
# Stands in for nplay: succeeds when both files exist.
[ -s "$1" ] && [ -s "$2" ] || { echo "fake nplay: missing files" >&2; exit 3; }
echo "fake nplay: playing $(basename "$1") and $(basename "$2")" >&2
