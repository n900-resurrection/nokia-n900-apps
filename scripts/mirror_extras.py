#!/usr/bin/env python3
"""Copy the first-boot tool packages of the Maemo Extras repositories into our mirror (sdk-mirror/, repository n900-resurrection/n900-sdk-mirror).

These are device packages, not SDK packages: what was needed to bring a stock N900 to life (a real bash, busybox, ssh, tmux, u-boot tools, ffmpeg).
The old Extras repositories are gone; the copy kept by maemo.plan9.de is the source. The packages go to pool/fremantle/free/ (the path they have there) and
the index to dists/fremantle/extras/free/binary-armel/Packages (apt line: `deb https://n900-resurrection.github.io/n900-sdk-mirror fremantle/extras free`
is not used by the devkit, the index is there for people and for apt). Every file is checked against the MD5sum of the source index.

Usage:  scripts/mirror_extras.py [--mirror sdk-mirror] [--card DIR]   (--card: compare with copies of the files, for example the memory card of a phone)
"""
import argparse, gzip, hashlib, re, sys, urllib.request
from pathlib import Path

BASE = "http://maemo.plan9.de/apt-mirror/mirror/repository.maemo.org/"
SOURCES = ["extras", "extras-devel", "extras-testing"]   # looked up in this order
# (package, version) ; the versions are the ones the phone was first set up with
PACKAGES = [
    ("bash3", "3.2-0maemo10"), ("busybox-power", "1.23.1power2"),
    ("openssh", "1:5.1p1-6.maemo5"), ("openssh-client", "1:5.1p1-6.maemo5"), ("openssh-common", "1:5.1p1-6.maemo5"), ("openssh-server", "1:5.1p1-6.maemo5"),
    ("rootsh", "1.8"), ("sudser", "0.2.0-4"), ("tmux", "1.6-2maemo2"), ("libevent-2.0-5", "2.0.10-stable-1"),
    ("tinysmb", "1.0.0"), ("tinysmbgui", "0.0.2"),
    ("u-boot-bootimg", "2013.04-1"), ("u-boot-flasher", "2013.04-2"), ("u-boot-tools", "2013.04-1"), ("u-boot-tools", "2013.04-2"),
    ("fiasco-image-update-ask", "0.4"), ("libfaad2-0", "2.0.0+cvs20040908+mp4v2+bmp-0ubuntu6maemo1"),
] + [(n, "4:0.5+svn20090706-5") for n in (
    "ffmpeg", "libavcodec52", "libavcodec-dev", "libavdevice52", "libavdevice-dev", "libavfilter0", "libavformat52", "libavformat-dev",
    "libavutil49", "libavutil-dev", "libpostproc51", "libpostproc-dev", "libswscale0", "libswscale-dev")]


def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": "n900-resurrection-mirror-tool"})
    return urllib.request.urlopen(req, timeout=120).read()


def parse(text):
    for blk in text.split("\n\n"):
        d, k = {}, None
        for line in blk.split("\n"):
            if line.startswith((" ", "\t")) and k:
                d[k] += "\n" + line
            elif ": " in line:
                k, _, v = line.partition(": ")
                d[k] = v
        if "Package" in d:
            yield d


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--mirror", default="sdk-mirror")
    ap.add_argument("--card")
    a = ap.parse_args()
    mirror = Path(a.mirror)
    idx = {}
    for src in SOURCES:
        text = None
        for u in (f"{BASE}{src}/dists/fremantle/free/binary-armel/Packages.gz", f"{BASE}dists/fremantle/{src}/free/binary-armel/Packages.gz"):
            try:
                text = gzip.decompress(get(u)).decode("utf-8", "replace")
                break
            except Exception:  # noqa: BLE001
                continue
        if text is None:
            sys.exit(f"index of {src} not found")
        for d in parse(text):
            d["_src"] = src
            idx.setdefault((d["Package"], d["Version"]), d)
    card = {p.name: p for p in Path(a.card).rglob("*.deb")} if a.card else {}
    out = []
    for name, ver in PACKAGES:
        d = idx.get((name, ver)) or sys.exit(f"{name} {ver} is in none of {SOURCES}")
        dest = mirror / d["Filename"]
        if not dest.is_file():
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes(get(f"{BASE}{d['_src']}/{d['Filename']}"))
        md5 = hashlib.md5(dest.read_bytes()).hexdigest()
        if md5 != d["MD5sum"]:
            dest.unlink()
            sys.exit(f"{dest.name}: MD5 {md5} does not match the index {d['MD5sum']}")
        note = ""
        c = card.get(dest.name)
        if c:
            note = " = card" if hashlib.md5(c.read_bytes()).hexdigest() == md5 else " DIFFERS from card"
        print(f"{name} {ver}: {int(d['Size']) // 1024} kB{note}")
        out.append(d)
    path = mirror / "dists/fremantle/extras/free/binary-armel/Packages"
    path.parent.mkdir(parents=True, exist_ok=True)
    out.sort(key=lambda d: (d["Package"], d["Version"]))
    path.write_text("\n\n".join("\n".join(f"{k}: {v}" for k, v in d.items() if not k.startswith("_")) for d in out) + "\n")
    print(f"index: {path} ({len(out)} packages)")


if __name__ == "__main__":
    main()
