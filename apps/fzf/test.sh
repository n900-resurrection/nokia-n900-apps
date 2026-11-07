TEST_NAME=fzf
need_pkg fzf
ok in-path sh -c 'command -v fzf'
t version '0.75' sh -c 'fzf --version | cut -d" " -f1'
t filter-best "ripgrep" sh -c 'printf "tmux\nripgrep\nvim9\nrsync\n" | fzf --filter=rpg | head -1'
t filter-exact "vim9" sh -c "printf 'tmux\nripgrep\nvim9\n' | fzf --filter=\"'vim\""
t filter-count "2" sh -c 'printf "alpha\nbeta\nalphabet\ngamma\n" | fzf --filter=alpha | wc -l | tr -d " "'
t filter-utf8 "Žluťoučký kůň" sh -c 'printf "kočka\nŽluťoučký kůň\n" | fzf --filter=zlutoucky'
ok shell-integration sh -c 'fzf --bash | grep -q "fzf-file-widget"'
summary
