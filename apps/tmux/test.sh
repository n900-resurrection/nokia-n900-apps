TEST_NAME=tmux
need_pkg tmux
export TERM=xterm
ok in-path sh -c 'command -v tmux'
ok no-missing-libs sh -c '! ldd /opt/tmux/bin/tmux 2>&1 | grep -q "not found"'
t version 'tmux 3.8' sh -c 'tmux -V'
ok desktop-entry test -r /usr/share/applications/hildon/tmux.desktop
# a detached session: create, run a command in it, read the screen, end it (no terminal needed)
ok new-session sh -c 'tmux -L ttest new-session -d -s t "sleep 30" && tmux -L ttest has-session -t t'
ok send-keys sh -c 'tmux -L ttest new-session -d -s k "sh" && tmux -L ttest send-keys -t k "echo tmux-works" Enter && sleep 1 && tmux -L ttest capture-pane -p -t k | grep -q tmux-works'
ok split-window sh -c 'tmux -L ttest split-window -d -t k && test "$(tmux -L ttest list-panes -t k | wc -l)" -eq 2'
ok kill-server sh -c 'tmux -L ttest kill-server; ! tmux -L ttest has-session 2>/dev/null'
summary
