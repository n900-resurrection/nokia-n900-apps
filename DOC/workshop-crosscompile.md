# Cross-compiling for Maemo 5 in a Workshop

**Moved.** The cross toolchain, the sysroot, the compiler wrapper `maemo-gcc` and the Workshop definition are part of the development kit
[n900-devkit](https://github.com/n900-resurrection/n900-devkit), which is the folder `devkit/` of this repository. Its documentation (in English, kept up to date):

- [devkit/docs/getting-started.md](../devkit/docs/getting-started.md): install LXD and Workshop, `make up toolchain sysroot ...`, with and without a phone, starting over, troubleshooting
- [devkit/docs/cross-compile.md](../devkit/docs/cross-compile.md): the sysroot from the Maemo mirrors, `maemo-gcc`, the versions of the libraries, rules of thumb
- [build-system.md](build-system.md): what this repository adds on top: `make debs`, packages, stamps, icons

The definition of the Workshop is `devkit/.workshop/n900.yaml` (linked as `.workshop/n900.yaml`), the sysroot script `devkit/scripts/fetch_sysroot.py` (linked as `scripts/fetch_sysroot.py`).
