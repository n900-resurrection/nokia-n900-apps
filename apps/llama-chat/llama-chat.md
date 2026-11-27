# llama-chat 0.1 on Maemo 5

Status 2026-11-17 (first version, the windows were checked in the emulator; the phone is next). A chat window for the story teller: [README.md](README.md). Build and packaging: [Makefile](Makefile)
(`make llama-chat`); conventions in [../../mk/app.mk](../../mk/app.mk).

Python 3 + [hildonlite](../hildonlite) on top of [llama2c](../llama2c): the engine runs as a child process, its standard output is read without blocking from a timer of the main loop (150 ms) and appended
to the text view, so the window stays responsive. The settings (model, temperature, top-p, length, memory) are in `~/.llama-chat/settings.json`; the models are the files in `~/MyDocs/llama2c` (the memory card) or, without a mounted card or for older installs, in `~/llama2c`.

## What is in it
- Chat view: entry + Send/Stop, the text of the story in a text view; the prompt of a turn is the end of the story (the last N words) and what you wrote; the echo of the prompt that the engine prints is dropped.
- Settings: the sliders, and the list of models (details, use, download, delete). Downloads: `curl -C -` into `.part`, size and SHA-256 are checked; a Hugging Face checkpoint is converted on the phone by `st2llama2c.py` (one tensor at a time, 80 MB peak).
- Catalogue `models.json`: stories260K (bundled in llama2c), stories15M, TinyStories 25M by Mxode (the licence is not stated by the author: downloaded from Hugging Face on request, not redistributed by us). Own entries: `~/.llama-chat/models.json`.

## Tests
`python3 apps/llama-chat/tests/test_llama_chat.py` (19 tests, a fake engine and `file://` downloads, a tiny Llama checkpoint through the real converter); on the phone `make -C apps/llama-chat test`.
