TEST_NAME=llama2c
need_pkg llama2c
ok engine-in-path test -x /usr/bin/llama2c
ok launcher-in-path test -x /usr/bin/llama-story
contains usage "Usage:" sh -c 'llama2c 2>&1'
contains tiny-story "Once upon a time" sh -c 'llama2c /opt/llama2c/share/llama2c/stories260K.bin -z /opt/llama2c/share/llama2c/tok512.bin -n 24 -s 1 -t 0.5 -i "Once upon a time"'
contains launcher-tiny "Once upon a time" sh -c 'llama-story -s -n 16 "Once upon a time" < /dev/null'
ok desktop-entry test -r /usr/share/applications/hildon/llama2c.desktop
ok man-pages sh -c 'test -r /opt/llama2c/share/man/man1/llama2c.1.gz && test -r /opt/llama2c/share/man/man1/llama-story.1.gz'
ok no-missing-libs sh -c "! ldd /opt/llama2c/bin/llama2c 2>&1 | grep -q \"not found\""
summary
