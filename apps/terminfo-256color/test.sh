TEST_NAME=terminfo-256color
need_pkg terminfo-256color
for t in x/xterm-256color s/screen-256color t/tmux-256color; do ok "installed-${t#*/}" test -r /usr/share/terminfo/$t; done
# Python curses (ranger) must see 256 colours with the new entry and 8 with the old one.
if [ -x /usr/bin/python3 ]; then
  contains colors-256 "256" env TERM=xterm-256color python3 -c "import curses;curses.setupterm();print(curses.tigetnum('colors'))"
  contains colors-8-default "8" env TERM=xterm python3 -c "import curses;curses.setupterm();print(curses.tigetnum('colors'))"
else skip python3 "python3 not installed"; fi
# The terminal of Maemo draws line characters through SO/SI (smacs ^N), not ESC ( 0: with the latter the frames of dialog are broken.
if [ -x /usr/bin/python3 ]; then
  contains acs-shift-out "x0e" env TERM=xterm-256color python3 -c "import curses;curses.setupterm();print(curses.tigetstr('smacs').hex().replace('0e','x0e'))"
fi
ok bashrc-block grep -q 'BEGIN terminfo-256color' /home/user/.bashrc
contains bashrc-effect "xterm-256color" su user -c 'TERM=xterm; . /home/user/.bashrc; echo $TERM'
summary
