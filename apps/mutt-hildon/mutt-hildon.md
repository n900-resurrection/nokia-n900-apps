# mutt-hildon: a graphical mail client on top of Mutt

A small Maemo 5 application (Python 2.5, PyGTK, python-hildon). It is a GUI layer over command line tools:
**it has no network code of its own, it only runs commands.**

| Task | Done by |
|---|---|
| read INBOX (list, message body) | `curl` 8.x (mbedTLS, TLS 1.3) over IMAP; the login goes through stdin, never the command line |
| send, reply | `msmtp` (the command from `set sendmail` in `~/.muttrc`) |
| full client | menu item **Open Mutt** starts `osso-xterm -e mutt` |

Why not Python `imaplib`: Python 2.5 uses OpenSSL 0.9.8 (TLS 1.0) and Centrum refuses TLS 1.0. Through curl it works.

The package depends on `mutt`, `msmtp`, `curl`, `python2.5`, `python-gtk2` and `python2.5-hildon`.

## Setup
There is none of its own. It reads `~/.muttrc` (`imap_user`, `folder`, `realname`, `from`, `sendmail`) and the password
from `~/.msmtp-password` (mode 600), like Mutt and msmtp do. Nothing secret is ever written to the repository.
```sh
(umask 077; read -s -p 'Password: ' p; echo; echo "$p" > ~/.msmtp-password)
```
Start it with the **Mail (Mutt)** icon in the menu or with `mutt-hildon`. Run it as the user `user`, not as root.

## Features (version 0.2)
- the 25 newest INBOX messages (sender, date, subject, Czech text works), refresh and "Older messages" (next page of history) from the menu,
- reading a message (text/plain, otherwise HTML with the tags removed), list of attachments (not saved yet),
- reply with a quote, new message, sending through msmtp, errors shown as banners,
- **Delete** (message menu): the message is copied to the trash folder from `set trash` in `~/.muttrc` and removed from INBOX.
  The Message-ID is checked first, so a changed mailbox never deletes the wrong message. EXPUNGE also removes other
  messages already flagged as deleted (for example by Mutt),
- **Settings** (main menu, saved in `~/.mutt-hildon.conf`): automatic refresh interval in minutes (default 0 = off, so
  mail is fetched only when the window opens or on Refresh), page size (25), ask before deleting, delete to trash,
- opening Mutt.

## Not yet
Move to other folders, the "seen" flag (curl `BODY[]` marks a message as read), folders other than INBOX, attachments, several
accounts, refresh while the application is closed, translations (gettext), address completion from the phone contacts.
These items are in [TODO.md](../../TODO.md).

## Tests
`make -C apps/mutt-hildon test`: package, files, .desktop entry and icons, strict Python 2.5 compilation, an offline
self-test of the back end (`/opt/mutt-hildon/selftest.py`: RFC 2047 headers, multipart, HTML, message building,
configuration) and, when the account is configured, a read-only INBOX listing. The window itself cannot be tested
without a display; it was tried by hand on the phone.

## Files
`mailcore.py` (back end without GUI), `mutt-hildon` (windows), `selftest.py`, `make-icon.sh` and `icons/` (ImageMagick
generated icons), `package.sh`, `test.sh`.
