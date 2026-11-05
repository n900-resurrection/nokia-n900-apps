# -*- coding: utf-8 -*-
# Mail back end for mutt-hildon: IMAP through curl (modern TLS), sending through msmtp.
# No GUI imports here, so it can be tested without a display (selftest.py).
# Python 2.5 (the Python of Maemo 5): no str.format, no "as" in except, no "with".
import os
import re
import shlex
import subprocess
import time
import email
import email.header
import email.utils
from email.mime.text import MIMEText

CURL = "/opt/curl/bin/curl"
CACERT = "/opt/curl/etc/ssl/cacert.pem"
END = "@@END@@"


class MailError(Exception):
    pass


def _rc_value(text, name):
    """Value of `set name = "value"` from a muttrc text (or None)."""
    m = re.search(r'^\s*set\s+%s\s*=\s*"([^"]*)"' % re.escape(name), text, re.M)
    return m and m.group(1) or None


def load_config(home=None):
    """Settings from ~/.muttrc (the same file as Mutt) and the password from ~/.msmtp-password."""
    home = home or os.path.expanduser("~")
    try:
        f = open(os.path.join(home, ".muttrc"))
        try:
            rc = f.read()
        finally:
            f.close()
    except IOError:
        raise MailError("Missing ~/.muttrc (see the mutt package: muttrc.centrum.example)")
    user = _rc_value(rc, "imap_user")
    folder = _rc_value(rc, "folder") or ""
    m = re.match(r"imaps?://([^/]+)/", folder)
    if not user or not m:
        raise MailError("~/.muttrc needs imap_user and folder = \"imaps://server/\"")
    password = None
    try:
        f = open(os.path.join(home, ".msmtp-password"))
        try:
            password = f.read().strip()
        finally:
            f.close()
    except IOError:
        pass
    sendmail = shlex.split(_rc_value(rc, "sendmail") or "/usr/bin/msmtp")
    return {
        "user": user,
        "host": m.group(1),
        "password": password,
        "realname": _rc_value(rc, "realname") or "",
        "from": _rc_value(rc, "from") or user,
        "sendmail": sendmail,
        "trash": (_rc_value(rc, "trash") or "").lstrip("+"),
    }


DEFAULT_SETTINGS = {"refresh_minutes": 0, "page_size": 25, "confirm_delete": 1, "delete_to_trash": 1, "cache_messages": 300}
SETTING_LIMITS = {"refresh_minutes": (0, 1440), "page_size": (5, 100), "confirm_delete": (0, 1), "delete_to_trash": (0, 1), "cache_messages": (50, 5000)}


def settings_path(home=None):
    return os.path.join(home or os.path.expanduser("~"), ".mutt-hildon.conf")


def load_settings(home=None):
    """Integer settings from ~/.mutt-hildon.conf (lines `key = value`); defaults and limits are applied."""
    res = dict(DEFAULT_SETTINGS)
    try:
        f = open(settings_path(home))
        try:
            lines = f.read().splitlines()
        finally:
            f.close()
    except IOError:
        return res
    for line in lines:
        m = re.match(r"\s*(\w+)\s*=\s*(-?\d+)\s*(#.*)?$", line)
        if m and m.group(1) in res:
            lo, hi = SETTING_LIMITS[m.group(1)]
            res[m.group(1)] = max(lo, min(hi, int(m.group(2))))
    return res


def save_settings(settings, home=None):
    f = open(settings_path(home), "w")
    try:
        f.write("# mutt-hildon settings (edited by the Settings dialog)\n")
        f.write("# refresh_minutes: automatic INBOX refresh, 0 = off\n")
        keys = DEFAULT_SETTINGS.keys()
        keys.sort()
        for k in keys:
            f.write("%s = %d\n" % (k, settings.get(k, DEFAULT_SETTINGS[k])))
    finally:
        f.close()


def _q(s):
    """Quote for a curl config file (-K)."""
    return s.replace("\\", "\\\\").replace('"', '\\"')


def curl(cfg, args):
    """Run curl against the IMAP server; the credentials go through stdin, never through the command line."""
    if not cfg.get("password"):
        raise MailError("No password: create ~/.msmtp-password (mode 600)")
    cmd = [CURL, "-s", "-S", "-K", "-", "--cacert", CACERT,
           "--connect-timeout", "20", "--max-time", "120"] + args
    p = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    out, err = p.communicate('user = "%s"\n' % _q(cfg["user"] + ":" + cfg["password"]))
    if p.returncode != 0:
        raise MailError(err.strip() or ("curl exit status %d" % p.returncode))
    return out


def decode_header(value):
    """RFC 2047 header to unicode. Whitespace between two encoded words is dropped, otherwise kept."""
    if not value:
        return u""
    if isinstance(value, unicode):
        return re.sub(r"\s+", u" ", value).strip()
    out = []
    prev_encoded = False
    for s, cs in email.header.decode_header(value):
        if cs:
            try:
                text = unicode(s, cs, "replace")
            except LookupError:
                text = unicode(s, "utf-8", "replace")
        else:
            text = unicode(s, "utf-8", "replace")
        if out and not (cs and prev_encoded):
            out.append(u" ")
        out.append(text)
        prev_encoded = bool(cs)
    return re.sub(r"\s+", u" ", u"".join(out)).strip()


def short_from(value):
    name, addr = email.utils.parseaddr(value or "")
    return decode_header(name) or addr or u"?"


def short_date(value):
    t = email.utils.parsedate_tz(value or "")
    if not t:
        return u""
    try:
        return unicode(time.strftime("%d.%m. %H:%M", time.localtime(email.utils.mktime_tz(t))))
    except (ValueError, OverflowError):
        return u""


def date_ts(value):
    """Unix time of a Date header (0 when it cannot be parsed); the sort key of the cache."""
    t = email.utils.parsedate_tz(value or "")
    try:
        return t and int(email.utils.mktime_tz(t)) or 0
    except (ValueError, OverflowError):
        return 0


def parse_header_block(raw):
    msg = email.message_from_string(raw.replace("\r\n", "\n"))
    return {"from": short_from(msg.get("From")), "subject": decode_header(msg.get("Subject")) or u"(no subject)",
            "date": short_date(msg.get("Date")), "ts": date_ts(msg.get("Date")), "message_id": (msg.get("Message-ID") or "").strip(), "from_raw": decode_header(msg.get("From"))}


def list_inbox(cfg, count=20, before=None):
    """`count` messages of INBOX, newest first: [{'idx', 'from', 'subject', 'date'}]. One connection.
    With before=<idx> the page starts right below that message index (older mail)."""
    base = "imaps://%s/INBOX" % cfg["host"]
    st = curl(cfg, [base, "-X", "STATUS INBOX (MESSAGES)"])
    m = re.search(r"MESSAGES (\d+)", st)
    if not m:
        raise MailError("Unexpected answer to STATUS: %r" % st[:80])
    total = int(m.group(1))
    top = before and min(before - 1, total) or total
    idxs = range(top, max(top - count, 0), -1)
    if not idxs:
        return []
    args = []
    for i in idxs:
        args.append("%s;MAILINDEX=%d;SECTION=HEADER.FIELDS%%20(FROM%%20SUBJECT%%20DATE%%20MESSAGE-ID)" % (base, i))
    args += ["-w", "\n%s\n" % END]
    out = curl(cfg, args)
    blocks = out.split("\n%s\n" % END)
    res = []
    for i, blk in zip(idxs, blocks):
        h = parse_header_block(blk)
        h["idx"] = i
        res.append(h)
    return res


def fetch_raw(cfg, idx):
    return curl(cfg, ["imaps://%s/INBOX;MAILINDEX=%d" % (cfg["host"], idx)])


def _strip_html(s):
    s = re.sub(r"(?is)<(script|style).*?</\1>", "", s)
    s = re.sub(r"(?i)<br\s*/?>|</p>|</div>|</tr>|</li>", "\n", s)
    s = re.sub(r"<[^>]+>", "", s)
    for a, b in (("&nbsp;", " "), ("&lt;", "<"), ("&gt;", ">"), ("&quot;", '"'), ("&#39;", "'"), ("&amp;", "&")):
        s = s.replace(a, b)
    return re.sub(r"\n{3,}", "\n\n", s).strip()


def _part_text(part):
    data = part.get_payload(decode=True) or ""
    cs = part.get_content_charset() or "utf-8"
    try:
        return unicode(data, cs, "replace")
    except LookupError:
        return unicode(data, "utf-8", "replace")


def parse_message(raw):
    """Raw RFC 822 message -> dict(from, to, subject, date, body, attachments). Body is plain text (HTML is stripped)."""
    msg = email.message_from_string(raw.replace("\r\n", "\n"))
    plain = html = None
    atts = []
    for part in msg.walk():
        if part.is_multipart():
            continue
        fn = part.get_filename()
        if fn or part.get("Content-Disposition", "").lower().startswith("attachment"):
            atts.append(decode_header(fn or "attachment"))
            continue
        ct = part.get_content_type()
        if ct == "text/plain" and plain is None:
            plain = _part_text(part)
        elif ct == "text/html" and html is None:
            html = _part_text(part)
    body = plain if plain is not None else (html is not None and _strip_html(html) or u"")
    return {"from": decode_header(msg.get("From")), "to": decode_header(msg.get("To")),
            "subject": decode_header(msg.get("Subject")), "date": decode_header(msg.get("Date")),
            "message_id": msg.get("Message-ID"), "body": body, "attachments": atts}


def delete(cfg, idx, message_id, to_trash=True):
    """Delete INBOX message number idx. Safety: the Message-ID must still match (the mailbox may have changed
    since the list was loaded). With to_trash the message is copied to the `trash` folder of ~/.muttrc first.
    EXPUNGE also removes other messages that are already flagged \\Deleted (for example by Mutt)."""
    base = "imaps://%s/INBOX" % cfg["host"]
    got = curl(cfg, ["%s;MAILINDEX=%d;SECTION=HEADER.FIELDS%%20(MESSAGE-ID)" % (base, idx)])
    if not message_id or message_id not in got:
        raise MailError("The mailbox changed, refresh the list first")
    if to_trash and cfg.get("trash"):
        curl(cfg, [base, "-X", 'COPY %d "%s"' % (idx, cfg["trash"])])
    curl(cfg, [base, "-X", "STORE %d +Flags \\Deleted" % idx])
    curl(cfg, [base, "-X", "EXPUNGE"])


def build_message(cfg, to, subject, body, in_reply_to=None):
    msg = MIMEText(body.encode("utf-8"), "plain", "utf-8")
    name = cfg.get("realname") or ""
    if name:
        frm = email.utils.formataddr((str(email.header.Header(name, "utf-8")), cfg["from"]))
    else:
        frm = cfg["from"]
    msg["From"] = frm
    msg["To"] = to
    msg["Subject"] = email.header.Header(subject, "utf-8")
    msg["Date"] = email.utils.formatdate(localtime=True)
    msg["Message-ID"] = email.utils.make_msgid()
    if in_reply_to:
        msg["In-Reply-To"] = in_reply_to
    return msg.as_string()


def recipients(to):
    return [a for n, a in email.utils.getaddresses([to]) if a]


def send(cfg, to, subject, body, in_reply_to=None):
    rcpt = recipients(to)
    if not rcpt:
        raise MailError("No recipient")
    text = build_message(cfg, to, subject, body, in_reply_to)
    p = subprocess.Popen(cfg["sendmail"] + ["--"] + rcpt, stdin=subprocess.PIPE,
                         stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    out, err = p.communicate(text)
    if p.returncode != 0:
        raise MailError((err or out).strip() or ("sendmail exit status %d" % p.returncode))


def reply_draft(msg):
    """(to, subject, quoted body) for a reply to a parse_message() result."""
    subj = msg["subject"]
    if not subj.lower().startswith("re:"):
        subj = u"Re: " + subj
    quoted = u"\n".join([u"> " + l for l in msg["body"].splitlines()])
    return msg["from"], subj, u"\n\n%s wrote:\n%s\n" % (msg["from"], quoted)
