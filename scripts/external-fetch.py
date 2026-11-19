#!/usr/bin/env python3
"""Fetch the packages of scripts/external.conf (releases of other authors) into build/external/ and check them. Run by `make external` and `make repo`.

    external-fetch.py [--conf FILE] [--dir DIR] [--check]

Prints the paths of the .deb files (one per line, relative to the project) on standard output, messages go to standard error.
A file is downloaded once; every run checks its SHA-256 and the control fields (Package = NAME, Architecture armel). Files in DIR that
are no longer in the conf are removed. Exit status 1 when a download or a check fails (nothing from that line is listed).
"""
import argparse, hashlib, os, shlex, subprocess, sys, urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))


def read_conf(path):
    out = []
    for n, line in enumerate(open(path, encoding="utf-8"), 1):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        f = shlex.split(line, comments=True)
        if len(f) < 5:
            sys.exit("%s:%d: expected NAME REPO TAG ASSET SHA256" % (path, n))
        e = dict(name=f[0], repo=f[1], tag=f[2], asset=f[3], sha256=f[4].lower())
        e.update(kv.split("=", 1) for kv in f[5:] if "=" in kv)
        if "/" in e["asset"] or len(e["sha256"]) != 64:
            sys.exit("%s:%d: bad asset or sha256" % (path, n))
        out.append(e)
    return out


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""):
            h.update(b)
    return h.hexdigest()


def control(path, field):
    return subprocess.run(["dpkg-deb", "-f", path, field], capture_output=True, text=True, check=True).stdout.strip()


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--conf", default=os.path.join(ROOT, "scripts", "external.conf"))
    ap.add_argument("--dir", default=os.path.join(ROOT, "build", "external"))
    a = ap.parse_args()
    entries = read_conf(a.conf)
    os.makedirs(a.dir, exist_ok=True)
    keep = {e["asset"] for e in entries}
    for f in os.listdir(a.dir):
        if f not in keep:
            os.remove(os.path.join(a.dir, f))
    bad = 0
    for e in entries:
        dest = os.path.join(a.dir, e["asset"])
        url = "https://github.com/%s/releases/download/%s/%s" % (e["repo"], e["tag"], e["asset"])
        try:
            if not os.path.exists(dest) or sha256(dest) != e["sha256"]:
                print("downloading %s" % url, file=sys.stderr)
                urllib.request.urlretrieve(url, dest + ".part")
                os.replace(dest + ".part", dest)
            if sha256(dest) != e["sha256"]:
                os.remove(dest)
                raise ValueError("the SHA-256 of the download differs from the one in external.conf (a changed release?)")
            if control(dest, "Package") != e["name"]:
                raise ValueError("Package is %s, not %s" % (control(dest, "Package"), e["name"]))
            if control(dest, "Architecture") != "armel":
                raise ValueError("Architecture is %s, not armel" % control(dest, "Architecture"))
        except Exception as ex:
            print("%s: %s" % (e["name"], ex), file=sys.stderr)
            bad += 1
            continue
        print("%s %s (%s, %s)%s" % (e["name"], control(dest, "Version"), e["repo"], e.get("license", "licence ?"),
                                    "  NOTE: " + e["note"] if e.get("note") else ""), file=sys.stderr)
        print(os.path.relpath(dest, ROOT))
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
