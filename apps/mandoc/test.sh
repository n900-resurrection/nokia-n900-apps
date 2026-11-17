TEST_NAME=mandoc
need_pkg mandoc
ok man-in-path sh -c '. /etc/profile.d/mandoc.sh; test "$(readlink -f "$(command -v man)")" = /opt/mandoc/bin/mandoc'
ok man-in-login-shell sh -c 'test "$(readlink -f "$(bash -lc "command -v man")")" = /opt/mandoc/bin/mandoc'
ok profile-script test -r /etc/profile.d/mandoc.sh
contains manpath "/opt/mandoc/share/man" sh -c '. /etc/profile.d/mandoc.sh; echo $MANPATH'
contains page-text "format manual pages" sh -c '. /etc/profile.d/mandoc.sh; man -T ascii mandoc | head -8'
contains page-of-other-package "tty-clock" sh -c '. /etc/profile.d/mandoc.sh; man -w tty-clock'
ok index-made test -s /opt/mandoc/share/man/mandoc.db
ok man-w-quiet sh -c '. /etc/profile.d/mandoc.sh; test -z "$(man -w mandoc 2>&1 >/dev/null)"'
contains apropos "mandoc" sh -c '. /etc/profile.d/mandoc.sh; apropos mandoc'
ok apt-hook test -r /etc/apt/apt.conf.d/50mandoc
summary
