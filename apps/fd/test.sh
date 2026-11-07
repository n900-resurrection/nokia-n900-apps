TEST_NAME=fd
need_pkg fd
ok in-path sh -c 'command -v fd'
t version 'fd 10.5.2' sh -c 'fd --version'
D=/home/user/fd-test; rm -rf $D; mkdir -p $D/sub $D/.hid; : > $D/report.txt; : > $D/sub/photo.png; : > $D/sub/note.md; : > $D/.hid/secret.txt
t find-by-name "report.txt" sh -c "cd $D && fd report"
t extension "sub/photo.png" sh -c "cd $D && fd -e png"
t skips-hidden "0" sh -c "cd $D && fd secret | wc -l | tr -d ' '"
t hidden-option ".hid/secret.txt" sh -c "cd $D && fd -H secret"
t type-dir "sub/" sh -c "cd $D && fd -t d sub"
t exec-command "./sub/note.md" sh -c "cd $D && fd -e md -x echo {}"
rm -rf $D
summary
