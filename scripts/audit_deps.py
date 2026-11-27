#!/usr/bin/env python3
"""Check that the dependencies of the packages of our repository can be satisfied by someone who installs from it.

    scripts/audit_deps.py DIR [DIR ...]  [--repo n900-repository/dists/fremantle/main/binary-armel/Packages]

Every DIR holds what a phone knows: `*Packages` files (copy /var/lib/apt/lists/*Packages of a phone, one DIR per phone) and optionally the file `status`
(/var/lib/dpkg/status). For the newest version of every package of the repository each Depends and Pre-Depends clause (with its alternatives and
version conditions) is looked up in: our repository, the stock and Extras lists, extras-devel and community-testing, and the installed packages.
It prints what cannot be satisfied anywhere, what only extras-devel / community-testing provide (a user without those catalogues cannot install it)
and what is only an installed package that no list has. It does not check Conflicts or files that two packages both contain
(for example bash3 and bash4-opt both install /bin/bash).
Found with it on 2026-11-26: apt-transport-curl wanted `bash3` where bash4-opt works as well; bt-kbmouse wants a package that no list has."""
import glob
import os
import re
import subprocess
import sys

args = [a for a in sys.argv[1:] if not a.startswith("--")]
OURS_FILE = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "n900-repository", "dists", "fremantle", "main", "binary-armel", "Packages")
if "--repo" in sys.argv:
    OURS_FILE = sys.argv[sys.argv.index("--repo") + 1]
    args = [a for a in args if a != OURS_FILE]
if not args:
    sys.exit(__doc__)
DIRS = args

def stanzas(path):
    cur = {}
    last = None
    for line in open(path, encoding="utf-8", errors="replace"):
        line = line.rstrip("\n")
        if not line.strip():
            if cur: yield cur
            cur, last = {}, None
        elif line[0] in " \t":
            if last: cur[last] += "\n" + line
        else:
            k, _, v = line.partition(":")
            last = k
            cur[k] = v.strip()
    if cur: yield cur

def split_deps(s):
    out = []
    for clause in s.split(","):
        clause = clause.strip()
        if not clause: continue
        alts = []
        for a in clause.split("|"):
            m = re.match(r"\s*([^\s(]+)\s*(?:\(\s*(<<|<=|=|>=|>>|<|>)\s*([^)\s]+)\s*\))?", a)
            if m: alts.append((m.group(1).split(":")[0], m.group(2), m.group(3)))
        if alts: out.append(alts)
    return out

# where the packages are: name -> list of (version, source)
AV = {}
PROV = {}
def add(st, source):
    if "Package" not in st:
        return
    n, v = st["Package"], st.get("Version", "0")
    AV.setdefault(n, []).append((v, source))
    for p in split_deps(st.get("Provides", "")):
        for name, op, ver in p:
            PROV.setdefault(name, []).append((n, source))

for f in [p for d in DIRS for p in glob.glob(os.path.join(d, "*Packages"))]:
    name = os.path.basename(f)
    if "n900-resurrection" in name: continue
    if "extras-devel" in name or "community-testing" in name: src = "devel"
    elif "maemo.nokia.com" in name or "linenoise" in name: src = "stock"
    else: src = "extras"
    for st in stanzas(f): add(st, src)
for f in [os.path.join(d, "status") for d in DIRS if os.path.exists(os.path.join(d, "status"))]:
    for st in stanzas(f):
        if "installed" in st.get("Status", "") and st["Status"].split()[-1] == "installed":
            add(st, "installed")
ours = list(stanzas(OURS_FILE))
for st in ours: add(st, "ours")

cache = {}
OPS = {"<<": "lt", "<": "lt", "<=": "le", "=": "eq", ">=": "ge", ">>": "gt", ">": "gt"}
def cmp_ok(have, op, want):
    key = (have, op, want)
    if key not in cache:
        cache[key] = subprocess.call(["dpkg", "--compare-versions", have, OPS[op], want]) == 0
    return cache[key]

def satisfied(alts):
    """-> (best source, alternative) or None; the source order: ours < stock < extras < installed < devel."""
    order = ["ours", "stock", "extras", "installed", "devel"]
    best = None
    for name, op, ver in alts:
        cands = [(v, s) for v, s in AV.get(name, []) if op is None or cmp_ok(v, op, ver)]
        if not cands and op is None:
            cands = [(None, s) for p, s in PROV.get(name, [])]
        for v, s in cands:
            if best is None or order.index(s) < order.index(best[0]):
                best = (s, name)
    return best

latest = {}
for st in ours:
    if "Package" in st:
        latest.setdefault(st["Package"], []).append(st)
bad, devel_only, installed_only = [], [], []
for n, sts in sorted(latest.items()):
    best = sts[0]                                          # the newest version of a package is what a new install gets
    for s in sts[1:]:
        if subprocess.call(["dpkg", "--compare-versions", s["Version"], "gt", best["Version"]]) == 0:
            best = s
    st = best
    for field in ("Pre-Depends", "Depends"):
        for alts in split_deps(st.get(field, "")):
            r = satisfied(alts)
            text = " | ".join(a + (f" ({o} {v})" if o else "") for a, o, v in alts)
            if r is None: bad.append((n, st["Version"], text))
            elif r[0] == "devel": devel_only.append((n, st["Version"], text, r[1]))
            elif r[0] == "installed": installed_only.append((n, st["Version"], text, r[1]))
print(f"{len(latest)} packages of ours checked ({sum(len(v) for v in latest.values())} versions in the pool)\n")
print("== NOT SATISFIABLE anywhere (not in our repo, stock, Extras, extras-devel, community-testing, nor installed):")
for n, v, t in bad: print(f"  {n} {v}: {t}")
print("\n== only in extras-devel / community-testing (users without those catalogues cannot install):")
for n, v, t, a in devel_only: print(f"  {n} {v}: {t}   [via {a}]")
print("\n== only as an installed package, in no list (installed by hand):")
for n, v, t, a in installed_only: print(f"  {n} {v}: {t}   [via {a}]")
