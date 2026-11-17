# llama2.c 0.0.20240529 on Maemo 5

Status 2026-11-17. Build and packaging: [Makefile](Makefile) (`make llama2c`, `make -C apps/llama2c <target>`); conventions in [../../mk/app.mk](../../mk/app.mk).

llama2.c (<https://github.com/karpathy/llama2.c>, MIT, Andrej Karpathy) is an inference engine for the Llama 2 architecture in one C file. The package has the engine (`llama2c`), the int8 variant (`llama2c-q8`),
the tiny model stories260K (1 MB, for tests) and a launcher `llama-story` that asks for the first words of a story and lets stories15M go on. A blog post tells the story of the decision.

## Measured on the test phone

| Model | Weights | File | Speed |
|---|---|---|---|
| stories15M | 15 M | 61 MB | **2.95 tokens/s** (the Pentium II of EXO Labs: 1.03) |
| stories42M | 42 M | 167 MB | **0.03 tokens/s**: it does not fit in RAM, every token reads the flash |

The weights are mapped read-only (`mmap`): clean pages, never written to the swap (the swap in use did not change during the runs: 157 to 160 MB, taken by other applications). **The rule: only models that fit
comfortably in RAM (about 160 MB at most).**

## Build

- `build.sh` clones the repository at a pinned commit (`COMMIT`, 350e04f), compiles `run.c` and `runq.c` with `maemo-gcc -O3 -ffast-math` (`-lrt` for `clock_gettime` of glibc 2.5) and downloads the tiny
  model with its tokenizer from huggingface.co/karpathy/tinyllamas (the SHA-256 is checked).
- `NEEDED`: librt and libc; the binaries have 26 kB each.

## Package `llama2c`

- `Depends: libc6 (>= 2.5), curl`, `Section: user/games`, 1.2 MB.
- `/usr/bin/llama2c`, `llama2c-q8`, `llama-story`; `/opt/llama2c/share/llama2c/{tokenizer.bin,stories260K.bin,tok512.bin}`; manuals `llama2c(1)` and `llama-story(1)`; `LICENSE`, `NOTICE`; a menu entry "Story teller".
- `llama-story`: asks before it downloads stories15M (61 MB, SHA-256 checked, to `~/llama2c`); without it, or with `-s`, or when there is less than 130 MB free, it uses stories260K.

## Verified

- On the test phone: installation, `make -C apps/llama2c test` (9 tests: both commands, usage, a story from the tiny model, the launcher in the tiny mode, the menu entry, the manuals, the libraries).
- stories15M with the engine: 2.95 tokens/s; the launcher with the downloaded model.

## Not verified

- The download inside the launcher (the model was copied by hand), the menu entry from the phone, `runq` (no quantized model yet: the export needs PyTorch).
