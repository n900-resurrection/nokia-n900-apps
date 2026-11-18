# Name: Story teller (llama-chat)
# Sourced by scripts/hildon-run.sh (INSIDE the Workshop) for: make hildon-run APP=llama-chat. A fake engine and a stub model in a scratch directory, no network.
RUN_SCRIPT=/project/apps/llama-chat/llama-chat
export LLAMACHAT_DIR=/tmp/llama-chat-demo/cfg LLAMACHAT_MODELS=/tmp/llama-chat-demo/models LLAMACHAT_ENGINE=/project/apps/llama-chat/tests/fake-engine.sh \
       LLAMACHAT_SHARE=/tmp/llama-chat-demo/share LLAMACHAT_CURL=curl
rm -rf /tmp/llama-chat-demo
mkdir -p "$LLAMACHAT_DIR" "$LLAMACHAT_MODELS" "$LLAMACHAT_SHARE"
printf 'abc' > "$LLAMACHAT_MODELS/stories15M.bin"
printf '[{"id": "stories15M", "name": "Stories 15M", "file": "stories15M.bin", "size": 3, "speed": 2.95, "license": "MIT", "params": "15 million weights"}]' > "$LLAMACHAT_DIR/models.json"
# screenshots: put lines like "export LLAMACHAT_OPEN=settings LLAMACHAT_DEMO_TEXT='» a robot\nand so on'" into build/llama-chat-env
[ -f /project/build/llama-chat-env ] && . /project/build/llama-chat-env
