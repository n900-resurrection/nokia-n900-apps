TEST_NAME=amfora
need_pkg amfora
ok in-path sh -c 'command -v amfora'
t version 'Amfora 1.11.0' sh -c 'amfora --version | head -1'
ok desktop-entry test -r /usr/share/applications/hildon/amfora.desktop
summary
