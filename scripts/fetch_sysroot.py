#!/usr/bin/env python3
"""Sestaví sysroot pro Maemo 5 (Fremantle, armel, glibc 2.5) z SDK repozitáře.

Stáhne index `Packages` z mirroru, vyřeší závislosti zadaných balíčků,
stáhne jen potřebné .deb a rozbalí je do ./sysroot (přes dpkg-deb -x).
Nestahuje celý mirror.

Použití:
    scripts/fetch_sysroot.py                       # výchozí sada -dev balíčků
    scripts/fetch_sysroot.py libgtk2.0-dev zlib1g-dev
    scripts/fetch_sysroot.py --dry-run             # jen vypíše, co by stáhl
    scripts/fetch_sysroot.py --list libncurses     # hledání v indexu

Stav: neotestováno na zařízení. Viz DOC/workshop-crosscompile.md.
"""
import argparse
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
DELAY = 0.3  # s mezi stahováním, ať nezatěžujeme cizí server


def fetch(url: str) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": "n900-sysroot-fetch/0.1"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read()


def parse_packages(text: str):
    """Vrátí {jmeno: [stanza,...]} (v indexu je víc verzí téhož balíčku)."""
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
            print(f"VAROVÁNÍ: {url}: {e}", file=sys.stderr)
            continue
        for name, lst in parse_packages(data.decode("utf-8", "replace")).items():
            pkgs.setdefault(name, []).extend(lst)
    if not pkgs:
        sys.exit("Index se nepodařilo načíst.")
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
    """Absolutní symlinky (např. usr/lib/libm.so -> /lib/libm.so.6) přepíše na relativní.

    Balíčky počítají s tím, že "/" je kořen zařízení. Mimo něj by odkaz vedl na hostitele
    a linker by hlásil "cannot open ... libm.so". Přepisuje jen odkazy, jejichž cíl v sysrootu je.
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
        rel = Path(__import__("os").path.relpath(dest, p.parent))
        p.unlink()
        p.symlink_to(rel)
        n += 1
    return n


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("roots", nargs="*", help="kořenové balíčky (výchozí: DEFAULT_ROOTS)")
    ap.add_argument("--sysroot", default="sysroot", help="cílový adresář (výchozí ./sysroot)")
    ap.add_argument("--cache", default="downloads", help="cache .deb (výchozí ./downloads)")
    ap.add_argument("--dry-run", action="store_true", help="jen vypsat plán")
    ap.add_argument("--list", metavar="TEXT", help="vypsat balíčky s TEXT v názvu a skončit")
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
    print(f"Balíčků: {len(chosen)}, přibližně {total / 1048576:.1f} MB")
    if missing:
        print("Nenalezeno v indexu (přeskočeno):", ", ".join(sorted(missing)))
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
            print(f"stahuji {n} {s['Version']}")
            deb.write_bytes(fetch(BASE + s["Filename"]))
            time.sleep(DELAY)
        subprocess.run(["dpkg-deb", "-x", str(deb), str(sysroot)], check=True)
    fixed = fix_symlinks(sysroot)
    print(f"Přepsáno absolutních symlinků na relativní: {fixed}")
    print(f"Hotovo: {sysroot.resolve()}")


if __name__ == "__main__":
    main()
