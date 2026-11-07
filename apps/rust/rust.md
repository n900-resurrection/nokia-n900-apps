# Rust on the N900

Verified 2026-11-07: a Rust program (std, 4 threads with channels, time, files, a TCP server and client on the loopback interface)
cross-built in the Workshop **runs on the phone** (kernel 2.6.28-omap1), 430 kB.

## How
- Target `armv7-unknown-linux-musleabi` (Tier 2, `rustup target add`): a **static** binary with its own musl libc, so the glibc 2.5 of the phone is
  not involved (the same idea as `CGO_ENABLED=0` for Go, see [../go/go.md](../go/go.md)). Soft-float ABI (no VFP needed), `-C target-cpu=cortex-a8`.
- Linker: the cross gcc of the Workshop (`arm-linux-gnueabi-gcc`); crt files and musl come with the target.
- `make -C apps/rust build` (installs rustup into `build/rust/`, about 765 MB, not in git, builds `src/rust/hello`, runs it under qemu-user),
  `make -C apps/rust push run DEVICE=n900`.
- `rustup-init` is fetched from static.rust-lang.org; its checksum is not pinned yet.

## TLS 1.3 (verified 2026-11-07)
`src/rust/tls` (`tls-rust [host] [path]`, rustls 0.23 with the `ring` provider, CA roots bundled by `webpki-roots`, 1 MB) makes an HTTPS request on the phone
and prints `TLS: TLSv1_3, TLS13_AES_128_GCM_SHA256`; howsmyssl.com confirms "TLS 1.3". The C/assembly of `ring` is built with the cross gcc
(`CC_armv7_unknown_linux_musleabi=arm-linux-gnueabi-gcc`). Copy it into `/home/user/apps`: `/tmp` of the phone is a 1 MB tmpfs.

## tokio (verified 2026-11-07)
`src/rust/async` (`async-rust`, tokio with the multi-thread runtime, timers, tasks, a TCP echo on the loopback interface and an HTTPS request through
tokio-rustls) runs on the phone: 4 tasks with timers after 208 ms, echo `ping`, `HTTP/1.1 200 OK`, TLS 1.3, the whole test in 1.3 s. So `mio`/epoll
works on the 2.6.28 kernel (it uses `epoll_wait`, not `epoll_pwait`). 1.2 MB.

## Limits and next steps
- Rust officially needs Linux 3.2+, the N900 runs 2.6.28. The hello program does not touch the missing syscalls (e.g. `epoll_pwait`, which
  made a patch of the Go runtime necessary). `tokio`/`mio` work (see above).
- Next: `presage`/`gurk-rs` for Signal (see [../../DOC/messengers.md](../../DOC/messengers.md)).
