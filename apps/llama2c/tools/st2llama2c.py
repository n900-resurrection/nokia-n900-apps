#!/usr/bin/env python3
"""Convert a Hugging Face Llama checkpoint (model.safetensors + config.json)
to the llama2.c "version 0" .bin format. Pure Python 3, no numpy, no torch.

    st2llama2c.py MODEL_DIR OUT.bin [--seq-len N]

MODEL_DIR holds config.json and model.safetensors (F32, F16 or BF16).
Only plain Llama models are accepted (no rope scaling, no biases, silu).
The result is read by `llama2c` with the 32000-token tokenizer.bin.
"""
import argparse, array, json, os, struct, sys


def read_safetensors(path):
    """Return (header dict, data offset, file object)."""
    f = open(path, "rb")
    (n,) = struct.unpack("<Q", f.read(8))
    header = json.loads(f.read(n))
    header.pop("__metadata__", None)
    return header, 8 + n, f


def tensor_floats(f, base, info):
    """The tensor as an array('f') (little endian), whatever its stored type."""
    a, b = info["data_offsets"]
    f.seek(base + a)
    raw = f.read(b - a)
    dt = info["dtype"]
    if dt == "F32":
        out = array.array("f")
        out.frombytes(raw)
    elif dt == "BF16":                      # the top 16 bits of a float32
        out = array.array("f")
        wide = bytearray(len(raw) * 2)
        wide[2::4] = raw[0::2]
        wide[3::4] = raw[1::2]
        out.frombytes(bytes(wide))
    elif dt == "F16":
        out = array.array("f", struct.unpack("<%de" % (len(raw) // 2), raw))
    else:
        sys.exit("unsupported tensor type " + dt)
    if sys.byteorder != "little":
        out.byteswap()
    return out


def unpermute(w, n_heads, rows, cols):
    """HF stores the q/k rows as (half, pair); llama2.c wants interleaved pairs."""
    hs = rows // n_heads
    out = array.array("f")
    for h in range(n_heads):
        for j in range(hs // 2):
            for t in (0, 1):
                r = h * hs + t * (hs // 2) + j
                out.extend(w[r * cols:(r + 1) * cols])
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("model_dir")
    ap.add_argument("out")
    ap.add_argument("--seq-len", type=int, default=512,
                    help="context length written to the header (default 512; the KV cache grows with it)")
    a = ap.parse_args()

    cfg = json.load(open(os.path.join(a.model_dir, "config.json")))
    if cfg.get("rope_scaling"):
        sys.exit("rope scaling is not supported")
    if cfg.get("attention_bias") or cfg.get("mlp_bias"):
        sys.exit("biases are not supported")
    if cfg.get("hidden_act", "silu") != "silu":
        sys.exit("only silu is supported")
    if cfg.get("rope_theta", 10000.0) != 10000.0:
        sys.exit("only rope_theta 10000 is supported by llama2.c")

    dim = cfg["hidden_size"]
    hidden = cfg["intermediate_size"]
    layers = cfg["num_hidden_layers"]
    heads = cfg["num_attention_heads"]
    kv_heads = cfg.get("num_key_value_heads", heads)
    vocab = cfg["vocab_size"]
    seq = min(a.seq_len, cfg["max_position_embeddings"])
    hs = dim // heads
    kv_dim = kv_heads * hs

    hdr, base, f = read_safetensors(os.path.join(a.model_dir, "model.safetensors"))

    def get(name, shape):
        if name not in hdr:
            sys.exit("tensor missing: " + name)
        if list(hdr[name]["shape"]) != list(shape):
            sys.exit("tensor %s has shape %s, expected %s" % (name, hdr[name]["shape"], shape))
        return tensor_floats(f, base, hdr[name])

    # The tensors are read and written one by one (the phone has 245 MB of RAM), in the order that llama2c expects.
    shared = "lm_head.weight" not in hdr or bool(cfg.get("tie_word_embeddings"))
    L = range(layers)
    p = "model.layers.%d."
    order = [lambda: get("model.embed_tokens.weight", (vocab, dim))]
    order += [lambda i=i: get(p % i + "input_layernorm.weight", (dim,)) for i in L]
    order += [lambda i=i: unpermute(get(p % i + "self_attn.q_proj.weight", (dim, dim)), heads, dim, dim) for i in L]
    order += [lambda i=i: unpermute(get(p % i + "self_attn.k_proj.weight", (kv_dim, dim)), kv_heads, kv_dim, dim) for i in L]
    order += [lambda i=i: get(p % i + "self_attn.v_proj.weight", (kv_dim, dim)) for i in L]
    order += [lambda i=i: get(p % i + "self_attn.o_proj.weight", (dim, dim)) for i in L]
    order += [lambda i=i: get(p % i + "post_attention_layernorm.weight", (dim,)) for i in L]
    order += [lambda i=i: get(p % i + "mlp.gate_proj.weight", (hidden, dim)) for i in L]       # w1
    order += [lambda i=i: get(p % i + "mlp.down_proj.weight", (dim, hidden)) for i in L]       # w2
    order += [lambda i=i: get(p % i + "mlp.up_proj.weight", (hidden, dim)) for i in L]         # w3
    order.append(lambda: get("model.norm.weight", (dim,)))
    order.append(lambda: array.array("f", bytes(4 * seq * hs // 2)))                          # the old freq_cis_real, skipped by the reader
    order.append(lambda: array.array("f", bytes(4 * seq * hs // 2)))                          # the old freq_cis_imag
    if not shared:
        order.append(lambda: get("lm_head.weight", (vocab, dim)))

    tmp = a.out + ".part"
    with open(tmp, "wb") as o:
        o.write(struct.pack("<7i", dim, hidden, layers, heads, kv_heads, vocab if shared else -vocab, seq))
        for part in order:
            o.write(part().tobytes())
    f.close()
    os.replace(tmp, a.out)
    print("%s: dim %d, hidden %d, %d layers, %d heads (%d kv), vocab %d%s, seq %d, %.1f MB" % (
        a.out, dim, hidden, layers, heads, kv_heads, vocab, " shared" if shared else "", seq, os.path.getsize(a.out) / 1e6))


if __name__ == "__main__":
    main()
