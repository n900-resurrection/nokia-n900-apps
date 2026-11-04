#!/usr/bin/env python3
"""Build a sysroot for Maemo 5 (Fremantle, armel, glibc 2.5) from the SDK repository.

Downloads the `Packages` index from a mirror, resolves the dependencies of the requested
packages, downloads only the .deb files that are needed and unpacks them into ./sysroot
(via dpkg-deb -x). It does not download the whole mirror.

Usage:
    scripts/fetch_sysroot.py                       # default set of -dev packages
    scripts/fetch_sysroot.py libgtk2.0-dev zlib1g-dev
    scripts/fetch_sysroot.py --dry-run             # only print what would be downloaded
    scripts/fetch_sysroot.py --list libncurses     # search the index

Status: verified by cross-compiling and running programs on a real N900 (2026-11).
See DOC/workshop-crosscompile.md.
"""
import argparse
import os
import re
import subprocess
import sys
import time
import urllib.request
from pathlib import Path

BASE = "http://maemo.plan9.de/apt-mirror/mirror/repository.maemo.org/"
# Fremantle SDK: dists/fremantle/sdk/{free,non-free}/binary-armel/Packages
INDEXES = [
    "dists/fremantle/sdk/free/binary-armel/Packages",
    "dists/fremantle/sdk/non-free/binary-armel/Packages",
]
DEFAULT_ROOTS = [
    "ncurses-base",   # terminfo data (/etc/terminfo), so that curses programs can run under qemu
    "libc6-dev",
    "zlib1g-dev",
    "libncurses5-dev",
    "libncursesw5-dev",
    "libssl-dev",
    "libglib2.0-dev",
    "libgtk2.0-dev",
    "libhildon1-dev",
    "libsdl1.2-dev",
    "libreadline5-dev",
]
DELAY = 0.3  # seconds between downloads, to go easy on somebody else's server


def fetch(url: str) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": "n900-sysroot-fetch/0.1"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read()


def parse_packages(text: str):
    """Return {name: [stanza, ...]} (the index holds several versions of the same package)."""
    pkgs = {}
    for block in text.split("\n\n"):
        if not block.strip():
            continue
        fields = {}
        key = None
        for line in block.splitlines():
            if line[:1] in (" ", "\t") and key:
                fields[key] += "\n" + line
            elif ":" in line:
                key, _, val = line.partition(":")
                fields[key] = val.strip()
        if "Package" in fields:
            pkgs.setdefault(fields["Package"], []).append(fields)
    return pkgs


def vercmp(a: str, b: str) -> int:
    if subprocess.run(["dpkg", "--compare-versions", a, "gt", b]).returncode == 0:
        return 1
    if subprocess.run(["dpkg", "--compare-versions", a, "lt", b]).returncode == 0:
        return -1
    return 0


def newest(stanzas):
    best = stanzas[0]
    for s in stanzas[1:]:
        if vercmp(s["Version"], best["Version"]) > 0:
            best = s
    return best


def dep_names(stanza):
    out = []
    for field in ("Depends", "Pre-Depends"):
        for part in stanza.get(field, "").split(","):
            part = part.strip()
            if not part:
                continue
            alts = [re.sub(r"\s*\(.*?\)", "", a).strip() for a in part.split("|")]
            out.append(alts)
    return out


def load_index():
    pkgs = {}
    for rel in INDEXES:
        url = BASE + rel
        try:
            data = fetch(url)
        except Exception as e:  # noqa: BLE001
            print(f"WARNING: {url}: {e}", file=sys.stderr)
            continue
        for name, lst in parse_packages(data.decode("utf-8", "replace")).items():
            pkgs.setdefault(name, []).extend(lst)
    if not pkgs:
        sys.exit("Could not load the package index.")
    return pkgs


def resolve(pkgs, roots):
    chosen, queue, missing = {}, list(roots), set()
    while queue:
        name = queue.pop(0)
        if name in chosen:
            continue
        if name not in pkgs:
            missing.add(name)
            continue
        st = newest(pkgs[name])
        chosen[name] = st
        for alts in dep_names(st):
            pick = next((a for a in alts if a in pkgs), None)
            if pick:
                queue.append(pick)
            else:
                missing.add(alts[0])
    return chosen, missing


def fix_symlinks(sysroot: Path) -> int:
    """Rewrite absolute symlinks (e.g. usr/lib/libm.so -> /lib/libm.so.6) as relative ones.

    The packages assume that "/" is the root of the device. Outside of it such a link would
    point to the host and the linker would report "cannot open ... libm.so". Only links whose
    target exists inside the sysroot are rewritten.
    """
    root = sysroot.resolve()
    n = 0
    for p in root.rglob("*"):
        if not p.is_symlink():
            continue
        target = Path(p.readlink())
        if not target.is_absolute():
            continue
        dest = root / str(target).lstrip("/")
        if not (dest.exists() or dest.is_symlink()):
            continue
        rel = Path(os.path.relpath(dest, p.parent))
        p.unlink()
        p.symlink_to(rel)
        n += 1
    return n


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("roots", nargs="*", help="root packages (default: DEFAULT_ROOTS)")
    ap.add_argument("--sysroot", default="sysroot", help="target directory (default ./sysroot)")
    ap.add_argument("--cache", default="downloads", help="download cache for .deb files (default ./downloads)")
    ap.add_argument("--dry-run", action="store_true", help="only print the plan")
    ap.add_argument("--list", metavar="TEXT", help="list packages with TEXT in the name and exit")
    a = ap.parse_args()

    pkgs = load_index()
    if a.list:
        for n in sorted(pkgs):
            if a.list in n:
                print(n, newest(pkgs[n])["Version"])
        return

    roots = a.roots or DEFAULT_ROOTS
    chosen, missing = resolve(pkgs, roots)
    total = sum(int(s.get("Size", 0)) for s in chosen.values())
    print(f"Packages: {len(chosen)}, approximately {total / 1048576:.1f} MB")
    if missing:
        print("Not found in the index (skipped):", ", ".join(sorted(missing)))
    if a.dry_run:
        for n, s in sorted(chosen.items()):
            print(f"  {n} {s['Version']}")
        return

    cache, sysroot = Path(a.cache), Path(a.sysroot)
    cache.mkdir(parents=True, exist_ok=True)
    sysroot.mkdir(parents=True, exist_ok=True)
    for n, s in sorted(chosen.items()):
        deb = cache / Path(s["Filename"]).name
        if not deb.exists():
            print(f"downloading {n} {s['Version']}")
            deb.write_bytes(fetch(BASE + s["Filename"]))
            time.sleep(DELAY)
        subprocess.run(["dpkg-deb", "-x", str(deb), str(sysroot)], check=True)
    fixed = fix_symlinks(sysroot)
    print(f"Absolute symlinks rewritten as relative: {fixed}")
    print(f"Done: {sysroot.resolve()}")


if __name__ == "__main__":
    main()
