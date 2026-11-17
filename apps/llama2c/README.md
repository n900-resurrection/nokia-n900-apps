# llama2c on the Nokia N900

A tiny language model on a phone from 2009: [llama2.c](https://github.com/karpathy/llama2.c) by Andrej Karpathy (one C file, MIT licence) with the small TinyStories models. They **continue a text**
(a child's story); they do not answer questions or hold a conversation, and they speak English only. `stories15M` runs at about **3 tokens per second** on the N900, which is about the speed of reading.

## Commands

| Command | What it is |
|---|---|
| `llama-story` | the launcher: asks for the first words of a story and tells it (also in the menu as *Story teller*) |
| `llama2c` | the engine itself, for any model of the llama2.c format |
| `llama2c-q8` | the same for int8 quantized models (version 2 of the format) |

## llama-story

```
llama-story [-s] [-n steps] [-t temperature] [first words ...]
```

| Switch | Meaning | Default |
|---|---|---|
| `-s` | use the tiny model stories260K (1 MB, in the package), no download | the model stories15M (61 MB) |
| `-n steps` | how many tokens to write (about 3 per second, so 200 is about a minute) | 200 |
| `-t temperature` | 0 is the surest word every time, 1 is freer, higher is wilder | 0.8 |
| *first words* | the beginning of the story; without them it asks | `Once upon a time` |

The model stories15M (61 MB) is **not in the package**. On the first run `llama-story` asks whether to download it (with `curl`, from huggingface.co), checks the SHA-256 and keeps it in `~/llama2c`
(or in the directory of the variable `LLAMA2C_MODELS`). It needs about 130 MB of free space. When you say no, or the download fails, the tiny model is used.

## llama2c (the engine)

```
llama2c <model.bin> [options]
llama2c ~/llama2c/stories15M.bin -z /opt/llama2c/share/llama2c/tokenizer.bin -t 0.8 -n 100 -i "One day"
```

| Option | Meaning | Default |
|---|---|---|
| `-i text` | the prompt, the beginning of the text | empty |
| `-n steps` | the number of tokens; 0 is the length of the context of the model | 256 |
| `-t temperature` | the temperature, from 0 up | 1.0 |
| `-p p` | the p of top-p (nucleus) sampling, 0 to 1 | 0.9 |
| `-s seed` | the random seed (the same seed and prompt give the same text) | the time |
| `-z file` | the tokenizer file | `tokenizer.bin` in the current directory |
| `-m mode` | `generate` or `chat` (chat only makes sense for a chat model) | `generate` |
| `-y text` | the system prompt in the chat mode | none |

The package has two tokenizers in `/opt/llama2c/share/llama2c/`: `tokenizer.bin` for the models of the Llama 2 size (stories15M, stories42M, stories110M) and `tok512.bin` for stories260K.
The numbers at the end ("achieved tok/s") are the speed.

## Which model

**A model has to fit in RAM.** The engine reads all the weights for every token, and the phone has 245 MB, most of it already used. stories15M (61 MB) runs at 3 tokens per second;
stories42M (167 MB) does not fit and takes half a minute per token. The weights are mapped read only, so they are never written to the swap (the flash memory is not worn by them).

More: `man llama-story`, `man llama2c`.
