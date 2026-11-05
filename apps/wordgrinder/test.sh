TEST_NAME=wordgrinder
need_pkg wordgrinder
contains help "WordGrinder version 0.8" wordgrinder --help
ok link-in-path test -x /usr/bin/wordgrinder
ok desktop-entry test -r /usr/share/applications/hildon/wordgrinder.desktop
summary
