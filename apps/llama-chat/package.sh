#!/bin/bash
# Package llama-chat as a .deb for Maemo 5: make -C apps/llama-chat deb
# Output: /project/build/deb/llama-chat_<VERSION>-<REV>_armel.deb
set -euo pipefail
PROJ=/project
. "$PROJ/scripts/debpack.sh"

PKG=llama-chat
VERSION="${VERSION:-0.1}"
STAGE="$PROJ/build/deb/stage-$PKG"
HERE="$PROJ/apps/llama-chat"

rm -rf "$STAGE"
mkdir -p "$STAGE/opt/$PKG" "$STAGE/usr/bin" "$STAGE/usr/share/applications/hildon" "$STAGE/DEBIAN"
install -m 755 "$HERE/llama-chat" "$STAGE/opt/$PKG/"
install -m 644 "$HERE/llama_chat.py" "$HERE/models.json" "$STAGE/opt/$PKG/"
install -m 644 "$PROJ/apps/llama2c/tools/st2llama2c.py" "$STAGE/opt/$PKG/"          # the converter of Hugging Face checkpoints (one source: llama2c/tools)
install -m 644 "$HERE/README.md" "$STAGE/opt/$PKG/"
for sz in 48 64; do
    mkdir -p "$STAGE/usr/share/icons/hicolor/${sz}x${sz}/apps"
    install -m 644 "$HERE/icons/$sz.png" "$STAGE/usr/share/icons/hicolor/${sz}x${sz}/apps/$PKG.png"
done
ln -s ../../opt/$PKG/llama-chat "$STAGE/usr/bin/llama-chat"
cat > "$STAGE/usr/share/applications/hildon/$PKG.desktop" <<'EOT'
[Desktop Entry]
Encoding=UTF-8
Version=1.0
Type=Application
Name=Story teller
Icon=llama-chat
Exec=/usr/bin/llama-chat
X-Osso-Type=application/x-executable
EOT

SECTION=user/games
DEPENDS="python3.11, python3-hildonlite (>= 0.4.0), llama2c (>= 0.0.20240529-1maemo2), curl"
DISPLAY_NAME="Story teller (chat window)"
SHORT_DESC="A chat window for tiny story-telling language models (llama2.c)"
LONG_DESC="A touch application on top of llama2c. You write the first words or a turn of a story, the model continues it token by token (about three tokens
per second on the N900, roughly the speed of reading). The menu of the title bar opens the settings: the model, the temperature, the length of a turn, top-p
and how much of the story the model remembers. The list of models shows the ones that can be downloaded (stories15M, 61 MB; TinyStories 25M, 98 MB,
which is converted on the phone from the Hugging Face checkpoint); the downloads are checked by SHA-256, and your own models can be added in
~/.llama-chat/models.json. Only models that fit in the RAM of the phone are offered. Upstream: this project (MIT); the engine is llama2.c by Andrej Karpathy (MIT)."
debpack_build
