#!/bin/bash
# Package llama2.c as a .deb for Maemo 5. Run INSIDE the Workshop after build.sh:
#   make -C apps/llama2c deb
# Output: /project/build/deb/llama2c_<VERSION>-<REV>_armel.deb
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=llama2c
VERSION="${VERSION:-0.0.20240529}"
OUT="$PROJ/build/out/$PKG-$VERSION"
SRC="$PROJ/build/upstream/llama2c"
HERE="$PROJ/apps/llama2c"
STAGE="$PROJ/build/deb/stage-$PKG"
[ -x "$OUT/llama2c" ] || { echo "Missing $OUT/llama2c, run build.sh first (make build)"; exit 1; }

rm -rf "$STAGE"
mkdir -p "$STAGE/opt/$PKG/bin" "$STAGE/opt/$PKG/share/$PKG" "$STAGE/opt/$PKG/share/doc/$PKG" "$STAGE/usr/bin"
install -m 755 "$OUT/llama2c" "$STAGE/opt/$PKG/bin/llama2c"
install -m 755 "$OUT/llama2c-q8" "$STAGE/opt/$PKG/bin/llama2c-q8"
install -m 755 "$HERE/llama-story" "$STAGE/opt/$PKG/bin/llama-story"
for c in llama2c llama2c-q8 llama-story; do ln -s "../../opt/$PKG/bin/$c" "$STAGE/usr/bin/$c"; done
# the tokenizer of the models of Llama 2 size, and the tiny demo model with its own tokenizer
install -m 644 "$OUT/tokenizer.bin" "$STAGE/opt/$PKG/share/$PKG/tokenizer.bin"
install -m 644 "$OUT/stories260K.bin" "$STAGE/opt/$PKG/share/$PKG/stories260K.bin"
install -m 644 "$OUT/tok512.bin" "$STAGE/opt/$PKG/share/$PKG/tok512.bin"
install -m 644 "$SRC/LICENSE" "$STAGE/opt/$PKG/share/doc/$PKG/LICENSE"
install -m 644 "$SRC/README.md" "$STAGE/opt/$PKG/share/doc/$PKG/README.md"
printf 'llama2.c by Andrej Karpathy (https://github.com/karpathy/llama2.c), MIT licence (LICENSE), commit 350e04f.\nThe models stories260K and stories15M are from https://huggingface.co/karpathy/tinyllamas (MIT licence). They were trained on the TinyStories dataset\n(Eldan and Li, 2023, https://huggingface.co/datasets/roneneldan/TinyStories), stories written by GPT-3.5 and GPT-4 for small children.\nThe package builds run.c and runq.c without a change; the launcher llama-story is ours.\n' > "$STAGE/opt/$PKG/share/doc/$PKG/NOTICE"
debpack_man "$HERE/llama2c.1" "$HERE/llama-story.1"
# a menu entry: the terminal of the phone starts the story teller
debpack_desktop "Story teller" "/usr/bin/llama-story" "$HERE/icon.png"

SECTION=user/games
DEPENDS="libc6 (>= 2.5), curl"
DISPLAY_NAME="Story teller (llama2.c)"
SHORT_DESC="A tiny language model that tells stories (llama2.c)"
LONG_DESC="llama2.c is Karpathy's inference engine for the Llama 2 architecture, one C file without dependencies. With the small TinyStories models it continues a few first words into a children's story: stories15M (15 million weights) runs at about 3 tokens per second on the N900.
llama-story asks for the first words of the story. The model of 61 MB is downloaded once to ~/llama2c on request; the tiny stories260K (1 MB) is in the package. llama2c is the engine itself (llama2c model.bin -i \"Once upon a time\"), llama2c-q8 reads int8 quantized models.
A model has to fit in RAM: bigger ones (stories42M, 167 MB) read the flash for every token and take half a minute per token.
Upstream: https://github.com/karpathy/llama2.c"
debpack_build
