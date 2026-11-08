#!/usr/bin/env python3
"""Compare the version of every application in apps/ with the newest upstream release (make updates).

Runs on the host, needs only the Python 3 standard library and network access. The upstream sources are listed in
scripts/upstream.conf. Results are cached for an hour in build/upstream-cache.json (use --refresh to ignore it).
GitHub allows 60 anonymous requests per hour: set GITHUB_TOKEN (or log in with `gh auth login`) for more.

  scripts/upstream-check.py [--apps a,b] [--only-new] [--json] [--refresh] [--no-color]
"""
import argparse
import concurrent.futures as cf
import json
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CACHE = os.path.join(ROOT, "build", "upstream-cache.json")
TTL = 3600
UA = "n900-upstream-check/1 (version comparison of packaged software)"
PRE = re.compile(r"(?i)(^|[^a-z])(rc|alpha|beta|pre|preview|dev|snapshot|test|nightly)([^a-z]|\d|$)")


# ---- versions ----------------------------------------------------------------------------------------------------

def vkey(v):
    """Comparable key: the runs of digits of a version (10.6p2 -> (10, 6, 2), 1.3-20260721 -> (1, 3, 20260721))."""
    return tuple(int(x) for x in re.findall(r"\d+", v))


def default_version(tag):
    """Version from a tag: drop a name prefix and v (tig-2.6.1, v1.2, release-3.0), '_' as '.' separator."""
    m = re.match(r"^(?:[A-Za-z][A-Za-z0-9]*?[-_]?)*?[vV]?(\d+(?:[._]\d+)*(?:p\d+)?)$", tag)
    return m.group(1).replace("_", ".") if m else None


def extract(tag, rx):
    if PRE.search(tag):
        return None
    if rx:
        m = re.search(rx, tag)
        return m.group(1).replace("_", ".") if m else None
    return default_version(tag)


def newest(versions, series=None):
    vs = [v for v in versions if v and (not series or v.startswith(series))]
    return max(vs, key=vkey) if vs else None


# ---- network -----------------------------------------------------------------------------------------------------

_token = None


def github_token():
    global _token
    if _token is None:
        _token = os.environ.get("GITHUB_TOKEN") or ""
        if not _token:
            try:
                _token = subprocess.run(["gh", "auth", "token"], capture_output=True, text=True, timeout=10).stdout.strip()
            except (OSError, subprocess.SubprocessError):
                _token = ""
    return _token


def get(url, headers=None):
    h = {"User-Agent": UA, "Accept": "*/*"}
    h.update(headers or {})
    if "api.github.com" in url and github_token():
        h["Authorization"] = "Bearer " + github_token()
    req = urllib.request.Request(url, headers=h)
    with urllib.request.urlopen(req, timeout=25) as r:
        return r.read().decode("utf-8", "replace")


def get_json(url):
    return json.loads(get(url))


# ---- sources -----------------------------------------------------------------------------------------------------

def src_github(ref, o):
    rx, series = o.get("re"), o.get("series")
    if not o.get("tags"):
        try:
            rel = get_json(f"https://api.github.com/repos/{ref}/releases?per_page=30")
            vs = [extract(r["tag_name"], rx) for r in rel if not r.get("prerelease") and not r.get("draft")]
            v = newest(vs, series)
            if v:
                return v
        except urllib.error.HTTPError as e:
            if e.code not in (404, 403):
                raise
            if e.code == 403:
                raise
    tags = get_json(f"https://api.github.com/repos/{ref}/tags?per_page=100")
    v = newest([extract(t["name"], rx) for t in tags], series)
    if not v:
        raise ValueError("no release or tag with a version")
    return v


def src_gitlab(ref, o):
    p = urllib.parse.quote(ref, safe="")
    tags = get_json(f"https://gitlab.com/api/v4/projects/{p}/repository/tags?per_page=100")
    v = newest([extract(t["name"], o.get("re")) for t in tags], o.get("series"))
    if not v:
        raise ValueError("no tag with a version")
    return v


def src_crate(ref, o):
    d = get_json(f"https://crates.io/api/v1/crates/{ref}")
    vs = [x["num"] for x in d["versions"] if not x["yanked"] and not PRE.search(x["num"])]
    return newest(vs, o.get("series"))


def src_gomod(ref, o):
    return get_json(f"https://proxy.golang.org/{ref}/@latest")["Version"].lstrip("v")


def src_pypi(ref, o):
    return get_json(f"https://pypi.org/pypi/{ref}/json")["info"]["version"]


def src_index(ref, o):
    rx = o.get("re")
    if not rx:
        raise ValueError("index needs re=")
    text = get(ref)
    vs = [m.group(1) for m in re.finditer(rx, text, re.M)]
    v = newest([x for x in vs if not PRE.search(x)], o.get("series"))
    if not v:
        raise ValueError("no version found on the page")
    return v


def src_golang(ref, o):
    d = get_json("https://go.dev/dl/?mode=json&include=all")
    v = newest([x["version"][2:] for x in d if x["stable"]], o.get("series"))
    if not v:
        raise ValueError("no stable Go release in the series")
    return v


SOURCES = {"github": src_github, "gitlab": src_gitlab, "crate": src_crate, "gomod": src_gomod, "pypi": src_pypi,
           "index": src_index, "golang": src_golang}


# ---- applications ------------------------------------------------------------------------------------------------

def read_conf():
    apps = {}
    for line in open(os.path.join(ROOT, "scripts", "upstream.conf"), encoding="utf-8"):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split(None, 3)
        name, kind, ref = parts[0], parts[1], parts[2]
        opts = {}
        for m in re.finditer(r'(\w+)=("([^"]*)"|\S+)', parts[3] if len(parts) > 3 else ""):
            opts[m.group(1)] = m.group(3) if m.group(3) is not None else m.group(2)
        apps[name] = (kind, ref, opts)
    return apps


def used_version(app, opts):
    mk = os.path.join(ROOT, "apps", app, "Makefile")
    if os.path.exists(mk):
        for line in open(mk, encoding="utf-8"):
            m = re.match(r"^(?:override\s+)?VERSION\s*[?:]?=\s*(\S+)", line)
            if m:
                return m.group(1)
    if "ver" in opts:
        f, _, rx = opts["ver"].partition(":")
        try:
            m = re.search(rx, open(os.path.join(ROOT, f), encoding="utf-8").read())
            return m.group(1) if m else None
        except OSError:
            return None
    return None


def check(app, kind, ref, opts, cache, refresh):
    used = used_version(app, opts)
    row = {"app": app, "used": used, "latest": None, "status": "", "source": f"{kind} {ref}".strip(" -"), "note": opts.get("note", "")}
    if kind == "local":
        row["status"], row["source"] = "own", "own package"
        return row
    if kind == "pinned":
        row["status"], row["source"] = "pinned", "commit"
        return row
    key = f"{kind} {ref} {opts.get('re','')} {opts.get('series','')} {opts.get('tags','')}"
    hit = cache.get(key)
    if hit and not refresh and time.time() - hit["t"] < TTL:
        latest = hit["v"]
    else:
        try:
            latest = SOURCES[kind](ref, opts)
        except Exception as e:  # noqa: BLE001 - report any failure in the row
            row["status"] = "error"
            row["note"] = (str(e) or type(e).__name__)[:60]
            return row
        cache[key] = {"t": time.time(), "v": latest}
    row["latest"] = latest
    if not used:
        row["status"] = "?"
    elif vkey(latest) > vkey(used):
        row["status"] = "NEW"
    elif vkey(latest) < vkey(used):
        row["status"] = "ahead"
    else:
        row["status"] = "ok"
    return row


# ---- output ------------------------------------------------------------------------------------------------------

ORDER = {"NEW": 0, "error": 1, "?": 2, "ahead": 3, "pinned": 4, "ok": 5, "own": 6}


def render(rows, color):
    c = (lambda code, s: f"\033[{code}m{s}\033[0m") if color else (lambda code, s: s)
    paint = {"NEW": "1;33", "ok": "32", "ahead": "36", "error": "31", "?": "31", "pinned": "2", "own": "2"}
    w = {k: max(len(k), *(len(str(r[k] or "-")) for r in rows)) for k in ("app", "used", "latest", "status", "source")}
    head = f"{'APP':<{w['app']}}  {'USED':<{w['used']}}  {'LATEST':<{w['latest']}}  {'STATUS':<{w['status']}}  {'SOURCE':<{w['source']}}  NOTE"
    out = [c("1", head)]
    for r in rows:
        status = r["status"]
        cells = (f"{r['app']:<{w['app']}}  {str(r['used'] or '-'):<{w['used']}}  {str(r['latest'] or '-'):<{w['latest']}}  ")
        arrow = c(paint[status], f"{status:<{w['status']}}")
        out.append(cells + arrow + f"  {r['source']:<{w['source']}}  {r['note']}")
    n = {s: sum(1 for r in rows if r["status"] == s) for s in ORDER}
    out.append("")
    out.append(", ".join(f"{n[s]} {name}" for s, name in (("NEW", "with a newer release"), ("ok", "up to date"), ("ahead", "newer than the release"),
                                                         ("pinned", "pinned"), ("own", "own"), ("?", "unknown version"), ("error", "failed")) if n[s]))
    return "\n".join(out)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--apps", help="comma separated list of applications (default: all)")
    ap.add_argument("--only-new", action="store_true", help="show only the applications with a newer release")
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--refresh", action="store_true", help="ignore the cache")
    ap.add_argument("--no-color", action="store_true")
    a = ap.parse_args()

    conf = read_conf()
    dirs = sorted(d for d in os.listdir(os.path.join(ROOT, "apps")) if os.path.isdir(os.path.join(ROOT, "apps", d)) and os.path.exists(os.path.join(ROOT, "apps", d, "Makefile")))
    want = [x for x in a.apps.replace(" ", ",").split(",") if x] if a.apps else dirs
    cache = {}
    try:
        cache = json.load(open(CACHE))
    except (OSError, ValueError):
        pass
    rows = []
    jobs = []
    with cf.ThreadPoolExecutor(8) as ex:
        for app in want:
            if app not in conf:
                rows.append({"app": app, "used": used_version(app, {}), "latest": None, "status": "?", "source": "(not in upstream.conf)", "note": ""})
                continue
            kind, ref, opts = conf[app]
            jobs.append(ex.submit(check, app, kind, ref, opts, cache, a.refresh))
        rows += [j.result() for j in jobs]
    os.makedirs(os.path.dirname(CACHE), exist_ok=True)
    json.dump(cache, open(CACHE, "w"))
    rows.sort(key=lambda r: (ORDER[r["status"]], r["app"]))
    if a.only_new:
        rows = [r for r in rows if r["status"] == "NEW"]
    if a.json:
        print(json.dumps(rows, indent=1))
    elif rows:
        print(render(rows, sys.stdout.isatty() and not a.no_color and not os.environ.get("NO_COLOR")))
    else:
        print("Nothing to update.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
