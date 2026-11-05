TEST_NAME=python3
need_pkg python3.11
contains version "3.11." python3 -c 'import sys; print(sys.version)'
t system-python-untouched 2.5 sh -c 'python -c "import sys; print \"%d.%d\" % sys.version_info[:2]"'
t arch-armel armv7l python3 -c 'import platform; print(platform.machine())'
t stdlib-json '{"a": [1, 2]}' python3 -c 'import json; print(json.dumps(json.loads("{\"a\":[1,2]}")))'
t unicode 'Příliš žluťoučký' python3 -c 'print("Příliš žluťoučký")'
t zlib 1000 python3 -c 'import zlib; print(len(zlib.decompress(zlib.compress(b"x"*1000))))'
t hashlib-sha256 2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824 python3 -c 'import hashlib; print(hashlib.sha256(b"hello").hexdigest())'
contains ssl-openssl3 "OpenSSL 3." python3 -c 'import ssl; print(ssl.OPENSSL_VERSION)'
t sqlite-version-ok True python3 -c 'import sqlite3; print(sqlite3.sqlite_version_info >= (3, 37, 0))'
t sqlite-roundtrip 'č 2' python3 -c '
import sqlite3
d = sqlite3.connect(":memory:"); d.execute("create table t(a, b)"); d.execute("insert into t values (?, ?)", ("č", 2))
print(*d.execute("select * from t").fetchone())'
t datetime-date 2026 python3 -c 'import datetime; print(datetime.date.today().year)'
t threads 10 python3 -c '
import threading
r = []
ts = [threading.Thread(target=lambda i=i: r.append(i)) for i in range(10)]
[t.start() for t in ts]; [t.join() for t in ts]
print(len(r))'
t subprocess hi python3 -c 'import subprocess; print(subprocess.check_output(["echo", "hi"]).decode().strip())'
t socket-loopback ok python3 -c '
import socket
s = socket.socket(); s.bind(("127.0.0.1", 0)); s.listen(1)
c = socket.create_connection(s.getsockname()); a, _ = s.accept(); c.sendall(b"ok"); print(a.recv(2).decode())'
t curses-wide ok python3 -c 'import _curses, _curses_panel; print("ok")'
t pty ok python3 -c 'import os; m, s = os.openpty(); os.close(m); os.close(s); print("ok")'
t ensurepip-present ok python3 -c 'import ensurepip; print("ok")'
# HTTPS to a real server through the ssl module: TLS 1.3 and a verified certificate (needs the network).
if /opt/curl/bin/curl -s -o /dev/null --max-time 10 https://www.python.org 2>/dev/null; then
    contains https-tls13 "TLSv1.3" python3 -c '
import socket, ssl
c = ssl.create_default_context()
s = c.wrap_socket(socket.create_connection(("www.python.org", 443), 15), server_hostname="www.python.org")
print(s.version())'
    contains urllib-https "200" python3 -c 'import urllib.request; print(urllib.request.urlopen("https://www.python.org", timeout=20).status)'
else
    skip https-tls13 "no network"
    skip urllib-https "no network"
fi
summary
