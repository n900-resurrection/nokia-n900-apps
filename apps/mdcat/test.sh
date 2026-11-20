TEST_NAME=mdcat
need_pkg mdcat
ok in-path sh -c 'command -v mdcat && command -v mdless'
ok static-binary sh -c '! ldd /opt/mdcat/bin/mdcat 2>&1 | grep -q "not found"'
t version 'mdcat 2.20.2' sh -c 'mdcat --version | head -1'
ok runs-as-user sh -c 'su user -c "mdcat --version" | head -1 | grep -q "mdcat 2.20"'
D=/home/user/mdcat-test; rm -rf $D; mkdir -p $D
printf '# Title\n\nSome *emphasis* and a [link](https://example.org).\n\n* one\n* two\n\n```python\nprint(1)\n```\n' > $D/t.md
ok heading sh -c "TERM=xterm mdcat --no-colour $D/t.md | grep -q Title"
ok list-and-link sh -c "TERM=xterm mdcat --no-colour $D/t.md | grep -q one && TERM=xterm mdcat --no-colour $D/t.md | grep -q 'example.org'"
ok code-block sh -c "TERM=xterm mdcat $D/t.md | grep -q 'print'"
ok stdin sh -c "printf '# Hi\n' | TERM=xterm mdcat --no-colour - | grep -q Hi"
ok license test -r /opt/mdcat/share/doc/mdcat/LICENSE
rm -rf $D
summary
