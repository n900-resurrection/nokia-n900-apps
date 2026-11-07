TEST_NAME=micro
need_pkg micro
ok in-path sh -c 'command -v micro'
t version 'Version: 2.0.15' sh -c 'micro -version | head -1'
ok desktop-entry test -r /usr/share/applications/hildon/micro.desktop
# micro needs a terminal to edit; without one it can still list its plugins and write its configuration directory
C=/home/user/micro-test-config; rm -rf $C
ok plugin-list sh -c "micro -config-dir $C -plugin list </dev/null"
rm -rf $C
summary
