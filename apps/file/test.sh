TEST_NAME=file
need_pkg file
ok in-path sh -c 'command -v file'
ok database test -r /opt/file/share/misc/magic.mgc
ok no-missing-libs sh -c '! ldd /opt/file/bin/file 2>&1 | grep -q "not found"'
t version 'file-5.48' sh -c 'file --version | head -1'
printf 'Ahoj svete\n' > /tmp/file-t.txt
t text-mime 'text/plain' sh -c 'file -b --mime-type /tmp/file-t.txt'
t elf 'application/x-executable' sh -c 'file -b --mime-type /bin/busybox | sed "s/pie-//"'
ok png sh -c 'f=$(ls /usr/share/icons/hicolor/48x48/apps/*.png | head -1); file -b --mime-type "$f" | grep -q image/png'
t directory 'inode/directory' sh -c 'file -b --mime-type /tmp'
ok script sh -c 'printf "#!/bin/sh\necho hi\n" > /tmp/file-t.sh; file -b --mime-type /tmp/file-t.sh | grep -q "text/x-shellscript"'
ok utf8-text sh -c 'file -b /tmp/file-t.txt | grep -q -i "text"'
rm -f /tmp/file-t.txt /tmp/file-t.sh
summary
