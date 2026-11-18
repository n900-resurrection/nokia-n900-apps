#!/bin/sh
# A stand-in for llama2c in the emulator and in demos: prints the prompt back, then a few words one by one, and the speed on stderr.
while [ $# -gt 0 ]; do [ "$1" = "-i" ] && prompt="$2"; shift; done
printf '%s' "$prompt"
for w in " and" " the" " little" " robot" " walked" " to" " the" " park" " and" " found" " a" " red" " ball." " It" " was" " a" " good" " day."; do
    sleep 0.25; printf '%s' "$w"
done
echo "achieved tok/s: 4.000000" >&2
