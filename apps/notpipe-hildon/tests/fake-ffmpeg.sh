#!/bin/sh
# Stands in for ffmpeg in the tests: "joins" the two inputs by concatenating them into the last argument (the output).
for a; do out=$a; done
v=; a=
while [ $# -gt 1 ]; do
    case "$1" in -i) if [ -z "$v" ]; then v=$2; else a=$2; fi; shift;; esac
    shift
done
case "$out" in *fail*) echo "fake ffmpeg: failed" >&2; exit 1;; esac
cat "$v" "$a" > "$out"
