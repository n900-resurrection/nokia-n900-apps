TEST_NAME=git
need_pkg git
contains version "git version 2.56" git --version
tmpdir
ok init-commit sh -c 'git init -q r && cd r && git config user.email t@t && git config user.name t && echo a > f && git add f && git commit -qm one'
t log-count 1 sh -c 'cd r && git log --oneline | wc -l'
contains ls-remote-https "refs/heads" git ls-remote https://github.com/elPytel/nokia-n900-notes.git
ok clone-https git clone -q --depth 1 https://github.com/elPytel/nokia-n900-notes.git c
summary
