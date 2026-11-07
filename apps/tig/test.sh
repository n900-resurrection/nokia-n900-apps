TEST_NAME=tig
need_pkg tig
ok in-path sh -c 'command -v tig'
ok no-missing-libs sh -c '! ldd /opt/tig/bin/tig 2>&1 | grep -q "not found"'
t version 'tig version 2.6.1' sh -c 'tig --version | head -1'
# a small repository (the interactive display was checked by hand in a pty: ssh -tt, tig showed the log)
D=/home/user/tig-test; rm -rf $D; mkdir -p $D; cd $D
git init -q . && git config user.email t@example.invalid && git config user.name Test && echo one > f && git add f && git commit -q -m "first commit" && echo two >> f && git commit -q -a -m "second commit"
ok repo-has-history sh -c "cd $D && git log --oneline | wc -l | grep -q 2"
cd /; rm -rf $D
summary
