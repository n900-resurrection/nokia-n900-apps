TEST_NAME=mutt-hildon
need_pkg mutt-hildon
ok files-present sh -c 'test -x /usr/bin/mutt-hildon && test -s /opt/mutt-hildon/mailcore.py'
ok desktop-entry test -s /usr/share/applications/hildon/mutt-hildon.desktop
ok icons sh -c 'test -s /usr/share/icons/hicolor/48x48/apps/mutt-hildon.png && test -s /usr/share/icons/hicolor/64x64/apps/mutt-hildon.png'
contains desktop-icon "Icon=mutt-hildon" cat /usr/share/applications/hildon/mutt-hildon.desktop
# Strict Python 2.5 syntax check of the GUI script (it cannot run without a display here).
ok gui-compiles python -c 'import py_compile,os; py_compile.compile("/opt/mutt-hildon/mutt-hildon", cfile="/home/user/.n900test.pyc", doraise=True); os.remove("/home/user/.n900test.pyc")'
# Offline self-test of the mail back end (header decoding, MIME, message building, config).
contains backend-selftest "0 failed" python /opt/mutt-hildon/selftest.py
# Online check only when the account is configured: read-only, lists INBOX through curl.
if [ -s /home/user/.msmtp-password ] && [ -s /home/user/.muttrc ]; then
    contains inbox-listing "messages" su user -c 'cd /opt/mutt-hildon && python -c "
import mailcore
c = mailcore.load_config()
print len(mailcore.list_inbox(c, 3)), \"messages\"
"'
else
    skip inbox-listing "no ~/.muttrc and ~/.msmtp-password for user"
fi
summary
