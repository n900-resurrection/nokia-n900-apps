TEST_NAME=copyparty
need_pkg copyparty
ok tree test -f /opt/copyparty/copyparty/__main__.py
ok bytecode sh -c 'ls /opt/copyparty/copyparty/__pycache__/*.pyc >/dev/null'
contains version 'copyparty v1.20.26' sh -c 'su user -c "copyparty --version" 2>&1 | head -n 3'
ok jinja-found sh -c 'su user -c "copyparty --version" 2>&1 | grep -q "jinja 2"'
ok config-made sh -c 'su user -c "copyparty-share config" >/dev/null && test -f /home/user/.copyparty/share.conf'
ok config-private sh -c '[ "$(stat -c %a /home/user/.copyparty/share.conf)" = 600 ]'

# the HTTP part: start in the background, wait for the port, check the login, an upload and a download, stop
copyparty-share stop >/dev/null 2>&1
copyparty-share start >/dev/null 2>&1
USER_=n900
PW=$(sed -n 's/^  n900: //p' /home/user/.copyparty/share.conf)
http() { # http <method> <path> <user:pass or -> [data]  -> prints the status code, the body in /tmp/cp-body
    python3 - "$@" <<'PY'
import sys, urllib.request, urllib.error, base64
m, path, cred = sys.argv[1:4]
data = sys.argv[4].encode() if len(sys.argv) > 4 else None
req = urllib.request.Request("http://127.0.0.1:3923" + path, data=data, method=m)
if cred != "-":
    req.add_header("Authorization", "Basic " + base64.b64encode(cred.encode()).decode())
try:
    r = urllib.request.urlopen(req, timeout=20); code, body = r.status, r.read()
except urllib.error.HTTPError as e:
    code, body = e.code, e.read()
open("/tmp/cp-body", "wb").write(body)
print(code)
PY
}
UP=0
for i in $(seq 1 45); do
    if python3 -c "import socket; socket.create_connection(('127.0.0.1', 3923), 1)" 2>/dev/null; then UP=1; break; fi
    sleep 1
done
ok port-opens test "$UP" = 1
echo "cp test file" > /home/user/MyDocs/cp-test-file.txt; chown user /home/user/MyDocs/cp-test-file.txt
refused() { c=$(http "$@"); case $c in 401|403) echo refused ;; *) echo "$c" ;; esac; }   # the server answers 401 or 403, both are a refusal
t no-login-no-access refused refused GET /cp-test-file.txt -
t wrong-password-refused refused refused GET /cp-test-file.txt "$USER_:wrong"
t login-reads-a-file 200 http GET /cp-test-file.txt "$USER_:$PW"
ok content sh -c 'grep -q "cp test file" /tmp/cp-body'
t upload 201 http PUT /cp-test-upload.txt "$USER_:$PW" "uploaded"
ok upload-lands-on-the-card sh -c 'grep -q uploaded /home/user/MyDocs/cp-test-upload.txt'
ok uploaded-file-belongs-to-user sh -c '[ "$(stat -c %U /home/user/MyDocs/cp-test-upload.txt)" = user ]'
contains status-running 'Running' copyparty-share status
rm -f /home/user/MyDocs/cp-test-file.txt /home/user/MyDocs/cp-test-upload.txt /tmp/cp-body
contains stop 'Stopped' copyparty-share stop
ok really-stopped sh -c '! python3 -c "import socket; socket.create_connection((\"127.0.0.1\", 3923), 1)" 2>/dev/null'
summary
