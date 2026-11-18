# llama-chat: the story teller with a chat window

A touch application for the N900 (Python 3 + [hildonlite](../hildonlite)) on top of [llama2c](../llama2c). The main view is a chat: write the first words
of a story (or a turn: "and then they met a dog"), tap **Send**, and the model continues the text token by token. **Stop** (the same button while the model
writes) cuts it short; an empty field and **Send** means "go on". The model only continues a text, it does not answer questions.

The title bar menu has **New story**, **Settings and models** and **About**.

## Settings
| | |
|---|---|
| Model | opens the list of models (below) |
| Temperature | 0.1 to 1.5, higher is wilder (default 0.8) |
| Top-p | 0.1 to 1.0, nucleus sampling (default 0.9) |
| Length of a turn | 16 to 400 tokens (default 200) |
| Memory | how many words of the story so far go into the prompt of the next turn, 0 to 150 (default 60). The engine reads the prompt token by token at the same speed as it writes, so a long memory makes a turn start later |

They are saved to `~/.llama-chat/settings.json`.

## Models
Tap a model for its details (size, speed on the N900, licence) and the actions **Use this model**, **Download** (with **Cancel download**), **Delete**.
The list comes from `models.json` of the package; add your own models in `~/.llama-chat/models.json` (the same fields, an entry with the same `id` replaces ours):

```json
[{"id": "mine", "name": "My model", "params": "15 million weights", "file": "mine.bin", "tokenizer": "tokenizer.bin",
  "size": 60816028, "sha256": "...", "url": "https://.../mine.bin", "license": "MIT", "speed": 2.9, "note": "..."}]
```
`tokenizer` is `tokenizer.bin` (the 32000 token Llama tokenizer, for the usual models) or `tok512.bin` (the tiny demo model). A Hugging Face checkpoint
(`config.json` + `model.safetensors`) is described by a `convert` block with the `files` to download (`name`, `url`, `size`, `sha256`); on the phone
`st2llama2c.py` (pure Python, no numpy) converts it to the llama2.c format. Models are kept in `~/llama2c`, the folder that `llama-story` uses as well.

**The rule: a model has to fit in the RAM of the phone** (about 160 MB; the weights are read on every token). `stories42M` (167 MB) ran at 0.03 tokens per second.
Larger models are marked and the download needs a confirmation.

| Model | File | Speed on the N900 |
|---|---|---|
| Tiny demo (stories260K), in the package | 1 MB | very fast, odd stories |
| Stories 15M | 61 MB | 2.95 tokens/s |
| TinyStories 25M (Mxode), converted on the phone | 98 MB | 2.45 tokens/s |

## Files
`llama-chat` (the windows), `llama_chat.py` (the logic: settings, catalogue, the engine as a child process, downloads, no GUI, tested on a PC with
`python3 tests/test_llama_chat.py`), `models.json`, `st2llama2c.py` (from `../llama2c/tools`). In the emulator: `make hildon-run APP=llama-chat`
(a fake engine, no network). Errors of the program: `~/.llama-chat/hildon.log`.
