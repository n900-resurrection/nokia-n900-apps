TEST_NAME=bat
need_pkg bat
ok in-path sh -c 'command -v bat'
ok batcat-alias sh -c 'batcat --version | grep -q "bat 0.26"'
t version 'bat 0.26.1' sh -c 'bat --version | cut -d" " -f1,2'
D=/home/user/bat-test; rm -rf $D; mkdir -p $D; printf 'def hello():\n    return "N900"\n' > $D/a.py
t plain "def hello():" sh -c "bat -p --color=never $D/a.py | head -1"
ok numbers sh -c "bat --color=never --decorations=always --style=numbers $D/a.py | grep -q '   1'"
ok highlights sh -c "bat --color=always -p $D/a.py | od -c | grep -q 033"
ok languages sh -c 'bat --list-languages | grep -q Python'
rm -rf $D
summary
