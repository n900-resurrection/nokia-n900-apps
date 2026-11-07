TEST_NAME=ripgrep
need_pkg ripgrep
ok in-path sh -c 'command -v rg'
t version 'ripgrep 15.2.0 (rev 393a398b68)' sh -c 'rg --version | head -1'
D=/home/user/rg-test; rm -rf $D; mkdir -p $D/sub $D/.hid; echo "alpha needle one" > $D/a.txt; echo "beta" > $D/sub/b.txt; echo "needle hidden" > $D/.hid/h.txt
t search-line "a.txt:1:alpha needle one" sh -c "cd $D && rg -n --with-filename needle a.txt"
ok skips-hidden sh -c "cd $D && ! rg -q hidden ."
ok hidden-option sh -c "cd $D && rg -q --hidden hidden ."
t files-list "3" sh -c "cd $D && rg --files --hidden | wc -l | tr -d ' '"
t regex "alpha needle one" sh -c "cd $D && rg -o 'a\w+ n\w+ \w+' a.txt"
ok gitignore sh -c "cd $D && mkdir .git; echo sub/ > .gitignore; ! rg -q beta ."
t utf8-case "Žluťoučký" sh -c "cd $D && printf 'Žluťoučký kůň\n' > u.txt && rg -io 'žluťoučký' u.txt"
rm -rf $D
summary
