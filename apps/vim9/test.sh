TEST_NAME=vim9
need_pkg vim9
export TERM=xterm   # without a terminal type vim behaves differently from a session on the phone
# The tests arrive on the stdin of one shell: vim gets </dev/null, otherwise it reads the rest of the tests as commands.
# redir! because redir fails when the file exists (E189). No & in a command: the lines are evaluated by the test helper.
ok in-path sh -c 'command -v vim9 && command -v xxd9'
ok no-missing-libs sh -c '! ldd /opt/vim9/bin/vim 2>&1 | grep -q "not found"'
ok system-vim-untouched sh -c 'vim --version | head -1 | grep -q "7\.2"'
ok desktop-entry test -r /usr/share/applications/hildon/vim9.desktop
t version 'VIM - Vi IMproved 9.2' sh -c 'vim9 --version | head -1 | cut -c1-21'
ok runtime-found sh -c 'vim9 -es -u /opt/vim9/share/vim/vimrc -c "redir! >/tmp/vim9.rt | echo \$VIMRUNTIME | redir END | q" </dev/null; grep -q /opt/vim9/share/vim/vim92 /tmp/vim9.rt'
# edit and save in the ex mode: UTF-8 (Czech) text survives
printf 'Ahoj svete\n' > /tmp/vim9.txt
ok edit-file sh -c 'vim9 -es -u NONE -c "%s/svete/světe/" -c wq /tmp/vim9.txt </dev/null; grep -q světe /tmp/vim9.txt'
# (-es skips the vimrc files, so the system vimrc is given with -u)
ok vimrc-settings sh -c 'vim9 -es -u /opt/vim9/share/vim/vimrc -c "redir! >/tmp/vim9.rt | set mouse? encoding? | redir END | q" </dev/null; grep -q encoding=utf-8 /tmp/vim9.rt'
ok syntax-runtime sh -c 'vim9 -es -u /opt/vim9/share/vim/vimrc -c "syntax on" -c "set ft=sh" -c "redir! >/tmp/vim9.rt | syntax | redir END | q" /tmp/vim9.txt </dev/null; grep -q shBracketExpr /tmp/vim9.rt'
ok xxd sh -c 'echo -n A | xxd9 | grep -q 41'
rm -f /tmp/vim9.txt /tmp/vim9.rt
summary
