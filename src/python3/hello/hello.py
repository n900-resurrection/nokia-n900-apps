#!/usr/bin/env python3
# Simple Python 3 program for the N900: system info, SQLite, an HTTPS request (TLS 1.3) and a small CPU benchmark.
# Run on the phone: python3 hello.py   (copy: scp src/python3/hello/hello.py n900:/home/user/)
import json
import platform
import sqlite3
import ssl
import sys
import time
import urllib.request

print("Python", sys.version.split()[0], "on", platform.machine(), platform.system(), platform.release())
print("OpenSSL:", ssl.OPENSSL_VERSION, "| SQLite:", sqlite3.sqlite_version)

db = sqlite3.connect(":memory:")
db.execute("create table words(w text)")
db.executemany("insert into words values (?)", [("Příliš",), ("žluťoučký",), ("kůň",)])
print("SQLite:", [r[0] for r in db.execute("select w from words order by w")])

t = time.time()
with urllib.request.urlopen("https://api.github.com/zen", timeout=20) as r:
    zen = r.read().decode()
print("HTTPS (%s, %.1f s): %s" % (r.status, time.time() - t, zen))

t = time.time()
n = sum(i * i for i in range(300000))
print("Loop of 300000 squares: %.2f s (result %d)" % (time.time() - t, n))
print(json.dumps({"ok": True, "when": time.strftime("%F %T")}))
