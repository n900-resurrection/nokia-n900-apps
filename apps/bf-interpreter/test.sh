TEST_NAME=bf-interpreter
need_pkg bf-interpreter
contains usage "Usage:" bf
ok link-in-path test -x /usr/bin/bf
ok example-installed test -r /opt/bf-interpreter/share/examples/hello_world.bf
contains hello-world "Hello World" bf /opt/bf-interpreter/share/examples/hello_world.bf
ok man-page test -r /opt/bf-interpreter/share/man/man1/bf.1.gz
ok no-missing-libs sh -c "! ldd /opt/bf-interpreter/bin/bf 2>&1 | grep -q \"not found\""
summary
