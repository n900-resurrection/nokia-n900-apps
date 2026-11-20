TEST_NAME=less
need_pkg less
ok binary test -x /opt/less/bin/less
ok static-ncurses sh -c '! ldd /opt/less/bin/less 2>&1 | grep -q "not found"'
t version 'less 710' sh -c '/opt/less/bin/less --version | head -1 | cut -d" " -f1,2'
ok runs-as-user sh -c 'su user -c "/opt/less/bin/less --version" | head -1 | grep -q "less 710"'
t reads-a-pipe 'second' sh -c 'printf "first\nsecond\nthird\n" | TERM=xterm /opt/less/bin/less -EFX | sed -n 2p'
t no-pager-for-a-short-file 'one line' sh -c 'printf "one line\n" > /home/user/less-t.txt; TERM=xterm /opt/less/bin/less -EFX /home/user/less-t.txt; rm -f /home/user/less-t.txt'
ok license test -r /opt/less/share/doc/less/COPYING
summary
