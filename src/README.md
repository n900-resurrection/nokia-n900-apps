# src: zdrojové kódy pro N900

Zatím jen [hello.c](hello.c), zkušební program pro Maemo 5 (armel, glibc 2.5).
Ověřeno 2026-11-04: přeloženo ve Workshopu a spuštěno na skutečném N900.

## Předpoklady (jednorázově)

Jednou za čas ze složky projektu (`/home/pytel/Git/N900`):

```bash
make up          # vytvoří a spustí Workshop "n900" (první spuštění)
make toolchain   # cross-gcc (armel) a qemu-user
make sysroot     # sysroot z Fremantle SDK do ./sysroot
```

Na N900 musí běžet SSH server a v `~/.ssh/config` na počítači musí být alias `n900`
(viz [../.env](../.env), `DEVICE=n900`). Postup přístupu je v [../DOC/workshop-crosscompile.md](../DOC/workshop-crosscompile.md)
a v poznámkách k SSH.

## 1. Sestavení

Překlad dělá wrapper [../scripts/maemo-gcc](../scripts/maemo-gcc) uvnitř Workshopu:

```bash
workshop exec n900 -- bash -c 'cd /project && mkdir -p build && scripts/maemo-gcc -O2 -o build/hello src/hello.c'
```

Zkratka, která navíc binárku zkusí spustit pod qemu proti sysrootu s glibc 2.5:

```bash
make hello
```

Výsledek je `build/hello` (ELF 32-bit ARM, EABI5). Zkontroluj, že potřebuje jen staré symboly glibc:

```bash
workshop exec n900 -- bash -c 'cd /project && arm-linux-gnueabi-objdump -T build/hello | grep GLIBC'
```

Očekávaný nejvyšší symbol je `GLIBC_2.4`. Když se objeví novější, nepoběží to na Maemo 5.

## 2. Zkopírování na N900

```bash
make push
```

Provede `scp build/hello n900:/home/user/apps/` (hodnoty `DEVICE`, `FILE`, `DEST` jsou v `.env` a `.env.default`).
Jiný soubor nebo cíl:

```bash
make push FILE=build/jiny DEST=/home/user/bin/
```

**Nekopíruj do `/home/user/MyDocs`.** Je to FAT oddíl s `noexec`, spuštění tam skončí `Permission denied`.

## 3. Vzdálené spuštění

```bash
ssh n900 /home/user/apps/hello
```

Očekávaný výstup:

```
Hello from Maemo 5 (armel, glibc 2.5)
```

Pokud binárka není spustitelná: `ssh n900 chmod +x /home/user/apps/hello`.
Cílová složka se při `make push` vytvoří automaticky (`ssh n900 mkdir -p ...`).

## Řešení potíží

| Příznak | Příčina / řešení |
|---|---|
| `no matching host key type found` | SSH jde na IP místo aliasu. Použij `n900` (alias v `~/.ssh/config` s `HostKeyAlgorithms +ssh-rsa`). |
| `Permission denied` při spuštění | Binárka leží v `MyDocs` (noexec), nebo nemá právo spuštění. |
| `GLIBC_2.xx not found` | Přeloženo bez `maemo-gcc`, nebo kód potřebuje novější glibc než 2.5. |
| `No route to host` / timeout | Telefon není na Wi-Fi nebo má jinou IP. |
| `make push` hlásí „Zadej DEVICE“ | Doplň `DEVICE=n900` do `.env`. |
