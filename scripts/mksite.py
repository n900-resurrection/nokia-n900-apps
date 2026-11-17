#!/usr/bin/env python3
"""Generate the package catalogue of the web site from the pool of the apt repository.

Reads every .deb in n900-repository/pool/main/<package>/, takes the newest version of each package (dpkg version order, epochs
included) and writes into the site repository (n900-resurrection.github.io):

    _data/packages.json              all packages with name, version, section, description, depends, sizes, links ...
    packages/<name>.md               one page per package (front matter only; the layout "package" of the theme draws it)
    install/packages/<name>.install  an install file for the Application Manager: adds our catalogue and offers the package (none for the
                                     packages needed before the catalogue works, BOOTSTRAP)
    assets/packages/icons/<name>.png the icon that is embedded in the package (XB-Maemo-Icon-26), else icons/packages/<name>.png of the main
                                     repository, else a plain one; all stored as 52x52

Nothing here is written by hand: the catalogue is what the packages say about themselves (control file of the .deb).

Usage:
    scripts/mksite.py --pool n900-repository/pool --site ../n900-resurrection.github.io [--icons icons/packages] [--base-url https://n900-resurrection.github.io/n900-repository]
"""
import argparse
import base64
import json
import re
import shutil
import struct
import subprocess
import sys
import zlib
from pathlib import Path


def control(deb: Path) -> dict:
    """Fields of the control file of a .deb (continuation lines are joined with newlines)."""
    out = subprocess.run(["dpkg-deb", "-f", str(deb)], capture_output=True, text=True, check=True).stdout
    fields, key = {}, None
    for line in out.splitlines():
        if line[:1] in (" ", "\t") and key:
            fields[key] += "\n" + line[1:]
        elif ":" in line:
            key, _, val = line.partition(":")
            fields[key] = val.strip()
    return fields


def vercmp(a: str, b: str) -> int:
    for op, r in (("gt", 1), ("lt", -1)):
        if subprocess.run(["dpkg", "--compare-versions", a, op, b]).returncode == 0:
            return r
    return 0


def newest(items):
    best = items[0]
    for it in items[1:]:
        if vercmp(it["Version"], best["Version"]) > 0:
            best = it
    return best


def plain_icon(path: Path):
    """A 26x26 grey rounded square (PNG written by hand, no library needed) for packages without an icon."""
    w = h = 26
    rows = []
    for y in range(h):
        row = bytearray([0])
        for x in range(w):
            inside = 1 <= x <= w - 2 and 1 <= y <= h - 2 and not ((x in (1, w - 2)) and (y in (1, h - 2)))
            row += bytes((0x78, 0x78, 0x78, 255)) if inside else bytes((0, 0, 0, 0))
        rows.append(bytes(row))
    raw = b"".join(rows)

    def chunk(tag, data):
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    path.write_bytes(png)


def to_52(path: Path, point: bool):
    """Icons are shown at 26 px and 52 px: store them at 52x52 (ImageMagick; left as they are when it is not installed)."""
    if not shutil.which("convert"):
        return
    args = ["convert", str(path), "-filter", "Point" if point else "Lanczos", "-resize", "52x52", str(path)]
    subprocess.run(args, check=False)


BOOTSTRAP = {"curl", "apt-transport-curl"}   # installed by hand with dpkg: the Application Manager cannot reach the repository without them

INSTALL_FILE = """[install]
catalogues = n900
package = {name}

[n900]
name = N900 Resurrection
uri = {base_url}
dist = fremantle
components = main
"""


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--pool", default="n900-repository/pool", help="pool directory of the repository")
    ap.add_argument("--site", required=True, help="the site repository (n900-resurrection.github.io)")
    ap.add_argument("--icons", default="icons/packages", help="directory with <package>.png for the packages that carry no icon in the .deb (scripts/make-pkg-icons.sh)")
    ap.add_argument("--base-url", default="https://n900-resurrection.github.io/n900-repository", help="address of the repository, for the download links")
    a = ap.parse_args()

    pool, site = Path(a.pool), Path(a.site)
    debs = sorted(pool.glob("main/*/*.deb"))
    if not debs:
        sys.exit(f"no .deb files in {pool}/main")
    by_name = {}
    for deb in debs:
        c = control(deb)
        c["_file"] = deb
        by_name.setdefault(c["Package"], []).append(c)

    (site / "_data").mkdir(parents=True, exist_ok=True)
    (site / "packages").mkdir(parents=True, exist_ok=True)
    icons = site / "assets" / "packages" / "icons"
    icons.mkdir(parents=True, exist_ok=True)
    for old in (site / "packages").glob("*.md"):         # a package that is gone from the pool leaves the catalogue
        if old.name != "index.md":
            old.unlink()

    out = []
    for name in sorted(by_name):
        versions = by_name[name]
        c = newest(versions)
        deb = c["_file"]
        desc = c.get("Description", "")
        short, _, long = desc.partition("\n")
        upstream = re.search(r"Upstream:\s*(\S+?)[.,;]?(?:\s|$)", long)
        icon = icons / f"{name}.png"
        central = Path(a.icons) / f"{name}.png"
        if c.get("XB-Maemo-Icon-26"):                      # the icon that the package carries (26x26): doubled with sharp pixels
            raw = base64.b64decode("".join(c["XB-Maemo-Icon-26"].split()))
            icon.write_bytes(raw)
            to_52(icon, point=True)
        elif central.is_file():                            # the icon of the catalogue
            shutil.copyfile(central, icon)
            to_52(icon, point=False)
        else:
            plain_icon(icon)
            to_52(icon, point=True)
        stat = deb.stat()
        rel = deb.relative_to(pool).as_posix()
        out.append({
            "name": name,
            "title": c.get("XB-Maemo-Display-Name") or name,
            "version": c["Version"],
            "section": c.get("Section", "user/other"),
            "short": short,
            "description": long,
            "depends": [d.strip() for d in c.get("Depends", "").split(",") if d.strip()],
            "installed_kb": int(c.get("Installed-Size", "0") or 0),
            "size": stat.st_size,
            "maintainer": c.get("Maintainer", ""),
            "upstream": upstream.group(1) if upstream else "",
            "file": deb.name,
            "url": f"{a.base_url}/pool/{rel}",
            "other_versions": sorted((v["Version"] for v in versions if v is not c), key=lambda s: s, reverse=True),
            "icon": f"/assets/packages/icons/{name}.png",
        })
        (site / "packages" / f"{name}.md").write_text(
            f"---\nlayout: package\ntitle: \"{(c.get('XB-Maemo-Display-Name') or name).replace(chr(34), chr(39))}\"\npkg: {name}\npermalink: /packages/{name}/\n---\n",
            encoding="utf-8")
    inst = site / "install" / "packages"
    shutil.rmtree(inst, ignore_errors=True)
    inst.mkdir(parents=True)
    for p in out:
        p["install"] = p["name"] not in BOOTSTRAP
        if p["install"]:
            (inst / f"{p['name']}.install").write_text(INSTALL_FILE.format(name=p["name"], base_url=a.base_url), encoding="utf-8")
    (site / "_data" / "packages.json").write_text(json.dumps(out, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
    sections = sorted({p["section"] for p in out})
    print(f"{len(out)} packages in {len(sections)} sections: {', '.join(sections)}")


if __name__ == "__main__":
    main()
