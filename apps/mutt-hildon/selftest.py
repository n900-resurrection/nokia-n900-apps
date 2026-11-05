# -*- coding: utf-8 -*-
# Offline self-test of mailcore.py (no network, no display). Run: python /opt/mutt-hildon/selftest.py
import os
import sys
import tempfile
import shutil
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mailcore

passed = []
failed = []


def check(name, got, want):
    if got == want:
        passed.append(name)
    else:
        failed.append(name)
        print "FAIL %s\n  want: %r\n  got:  %r" % (name, want, got)

check("rfc2047-b", mailcore.decode_header("=?UTF-8?B?xI1lc2vDvSDDunTDqXI=?="), u"česk\xfd \xfat\xe9r")
check("rfc2047-q", mailcore.decode_header("=?iso-8859-2?Q?=E8au?= ahoj"), u"čau ahoj")
check("from-name", mailcore.short_from('"=?UTF-8?B?xI1lc2vDvQ==?=" <a@b.cz>'), u"česk\xfd")
check("from-addr-only", mailcore.short_from("a@b.cz"), u"a@b.cz")
check("date-bad", mailcore.short_date("nonsense"), u"")
h = mailcore.parse_header_block("From: Steam <n@s.com>\r\nSubject: Hello\r\n there\r\nDate: Thu, 05 Nov 2026 08:10:52 -0800\r\n\r\n")
check("header-folded-subject", h["subject"], u"Hello there")
check("header-date-format", len(h["date"]), 12)

mp = ("From: A <a@x.cz>\nTo: b@x.cz\nSubject: =?UTF-8?Q?P=C5=99=C3=ADloha?=\nMIME-Version: 1.0\n"
      "Content-Type: multipart/mixed; boundary=XX\n\n--XX\nContent-Type: text/plain; charset=utf-8\n"
      "Content-Transfer-Encoding: 8bit\n\nAhoj \xc4\x8d\xc3\xa1ra\n--XX\nContent-Type: application/pdf; name=\"f.pdf\"\n"
      "Content-Disposition: attachment; filename=\"f.pdf\"\nContent-Transfer-Encoding: base64\n\nAAAA\n--XX--\n")
m = mailcore.parse_message(mp)
check("multipart-body", m["body"].strip(), u"Ahoj č\xe1ra")
check("multipart-attachment", m["attachments"], [u"f.pdf"])
check("multipart-subject", m["subject"], u"Př\xedloha")
ht = "From: a@x.cz\nSubject: h\nContent-Type: text/html; charset=utf-8\n\n<html><style>p{}</style><body><p>Hi &amp; bye</p><br>next</body></html>\n"
check("html-fallback", mailcore.parse_message(ht)["body"], u"Hi & bye\n\nnext")

cfg = {"user": "u@c.cz", "host": "h", "password": "x", "realname": u"J\xe1ra", "from": "u@c.cz", "sendmail": ["cat"]}
raw = mailcore.build_message(cfg, "b@x.cz", u"čau", u"tělo", "<id@x>")
back = mailcore.parse_message(raw)
check("build-roundtrip-body", back["body"].strip(), u"tělo")
check("build-roundtrip-subject", back["subject"], u"čau")
check("build-from-name", mailcore.short_from(mailcore.parse_message(raw)["from"]), u"J\xe1ra")
check("build-in-reply-to", "In-Reply-To: <id@x>" in raw, True)
check("recipients", mailcore.recipients("A <a@x.cz>, b@y.cz"), ["a@x.cz", "b@y.cz"])
check("reply-subject", mailcore.reply_draft({"from": u"A", "subject": u"Re: x", "body": u"l1\nl2"})[1], u"Re: x")
check("reply-quote", u"> l2" in mailcore.reply_draft({"from": u"A", "subject": u"x", "body": u"l1\nl2"})[2], True)
check("quote-escape", mailcore._q('a"b\\c'), 'a\\"b\\\\c')

d = tempfile.mkdtemp()
try:
    f = open(os.path.join(d, ".muttrc"), "w")
    f.write('set imap_user = "me@centrum.cz"\nset folder = "imaps://imap.centrum.cz/"\n'
            'set sendmail = "/usr/bin/msmtp -a centrum"\nset realname = "Me"\n')
    f.close()
    c = mailcore.load_config(d)
    check("config-host", c["host"], "imap.centrum.cz")
    check("config-sendmail", c["sendmail"], ["/usr/bin/msmtp", "-a", "centrum"])
    check("config-nopassword", c["password"], None)
    try:
        mailcore.curl(c, ["x"])
        check("curl-needs-password", "no error", "MailError")
    except mailcore.MailError:
        check("curl-needs-password", 1, 1)
finally:
    shutil.rmtree(d)

# Paging: list_inbox(before=...) asks curl for the right message indexes (curl is replaced by a fake).
calls = []
def fake_curl(cfg, args):
    if "-X" in args:
        return "* STATUS INBOX (MESSAGES 60)\r\n"
    calls.append(args)
    return "".join(["Subject: s\n\n\n%s\n" % mailcore.END] * (len(args) - 2))
real_curl = mailcore.curl
mailcore.curl = fake_curl
try:
    first = mailcore.list_inbox({"host": "h"}, 25)
    older = mailcore.list_inbox({"host": "h"}, 25, before=first[-1]["idx"])
    check("paging-first", (first[0]["idx"], first[-1]["idx"]), (60, 36))
    check("paging-older", (older[0]["idx"], older[-1]["idx"]), (35, 11))
    check("paging-end", [h["idx"] for h in mailcore.list_inbox({"host": "h"}, 25, before=3)], [2, 1])
finally:
    mailcore.curl = real_curl

# Settings: defaults, limits, round trip.
d = tempfile.mkdtemp()
try:
    check("settings-defaults", mailcore.load_settings(d)["page_size"], 25)
    f = open(mailcore.settings_path(d), "w")
    f.write("page_size = 9999\nrefresh_minutes = 15  # comment\nbogus = 3\n")
    f.close()
    st = mailcore.load_settings(d)
    check("settings-limit", st["page_size"], 100)
    check("settings-value", st["refresh_minutes"], 15)
    st["confirm_delete"] = 0
    mailcore.save_settings(st, d)
    check("settings-roundtrip", mailcore.load_settings(d)["confirm_delete"], 0)
finally:
    shutil.rmtree(d)

# Delete: the Message-ID guard and the command sequence (curl is faked).
cmds = []
def fake_curl2(cfg, args):
    if any(["MESSAGE-ID" in a for a in args]):
        return "Message-ID: <abc@x>\r\n\r\n"
    cmds.append(args[-1])
    return ""
mailcore.curl = fake_curl2
try:
    c2 = {"host": "h", "trash": "ko&AWE-"}
    try:
        mailcore.delete(c2, 5, "<other@x>")
        check("delete-guard", "deleted", "MailError")
    except mailcore.MailError:
        check("delete-guard", cmds, [])
    mailcore.delete(c2, 5, "<abc@x>")
    check("delete-sequence", cmds, ['COPY 5 "ko&AWE-"', "STORE 5 +Flags \\Deleted", "EXPUNGE"])
finally:
    mailcore.curl = real_curl

# Store: cache, reconcile, bodies, outbox, flush (in-memory database).
import store
def hdr(i, mid, ts, subj=u"s"):
    return {"idx": i, "message_id": mid, "from": u"F", "subject": subj, "date": u"d", "ts": ts}
st = store.Store(":memory:")
st.upsert_headers([hdr(1, "<a>", 100), hdr(2, "<b>", 200), hdr(3, "<c>", 300)])
check("store-order", [r["message_id"] for r in st.page(10)], ["<c>", "<b>", "<a>"])
st.set_body("<b>", {"body": u"t\u011blo", "attachments": [u"x.pdf"], "to": u"t", "date": u"D"})
st.upsert_headers([hdr(5, "<b>", 200, u"new subject")])
check("store-body-kept", st.get_body("<b>")["body"], u"t\u011blo")
check("store-idx-updated", [r["idx"] for r in st.page(10) if r["message_id"] == "<b>"], [5])
check("store-no-body", st.get_body("<a>"), None)
st.reconcile([hdr(4, "<c>", 300)])              # server now has only <c> from ts 300 on
check("reconcile-keeps-older", st.count(), 3)
st.reconcile([hdr(4, "<c>", 300), hdr(3, "<a>", 100)])  # range from 100: <b> was deleted on the server
check("reconcile-removes", sorted([r["message_id"] for r in st.page(10)]), ["<a>", "<c>"])
st.prune(1)
check("prune", [r["message_id"] for r in st.page(10)], ["<c>"])
st.outbox_add(u"x@y.cz", u"S", u"B", None, u"offline")
st.outbox_add(u"z@y.cz", u"S2", u"B2", None, u"offline")
check("outbox-count", st.outbox_count(), 2)
def fail_send(cfg, to, subject, body, irt):
    raise mailcore.MailError("no network")
check("flush-offline", store.flush_outbox({}, st, fail_send), (0, 2, u"no network"))
check("outbox-error-saved", st.outbox_list()[0]["error"], u"no network")
sent_to = []
def ok_send(cfg, to, subject, body, irt):
    sent_to.append(to)
check("flush-online", store.flush_outbox({}, st, ok_send), (2, 0, None))
check("flush-order", sent_to, [u"x@y.cz", u"z@y.cz"])
st.close()

print "selftest: %d passed, %d failed" % (len(passed), len(failed))
sys.exit(len(failed) and 1 or 0)
