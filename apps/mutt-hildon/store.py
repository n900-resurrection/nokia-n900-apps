# -*- coding: utf-8 -*-
# Local SQLite store for mutt-hildon: cached message headers and bodies (fast start, offline reading)
# and the outbox of messages that could not be sent. Python 2.5 sqlite3 (SQLite 3.6 on the device).
# A connection must stay in the thread that made it, so every background job opens its own Store.
import os
import time
import sqlite3

SCHEMA = """
CREATE TABLE IF NOT EXISTS messages (
    message_id TEXT PRIMARY KEY, idx INTEGER, sender TEXT, subject TEXT, date_txt TEXT, ts INTEGER,
    body TEXT, atts TEXT, to_txt TEXT, full_date TEXT, fetched INTEGER);
CREATE INDEX IF NOT EXISTS messages_ts ON messages (ts);
CREATE TABLE IF NOT EXISTS outbox (
    id INTEGER PRIMARY KEY AUTOINCREMENT, to_addr TEXT, subject TEXT, body TEXT, in_reply_to TEXT,
    created INTEGER, error TEXT);
"""


def default_path():
    d = os.path.join(os.path.expanduser("~"), ".mutt-hildon")
    if not os.path.isdir(d):
        os.makedirs(d)
    return os.path.join(d, "cache.db")


class Store:
    def __init__(self, path=None):
        self.db = sqlite3.connect(path or default_path())
        self.db.executescript(SCHEMA)
        self.db.commit()

    def close(self):
        self.db.close()

    # ---- message headers ----
    def upsert_headers(self, items):
        """items: dicts from mailcore.list_inbox. Cached bodies are kept."""
        for h in items:
            if not h.get("message_id"):
                continue
            cur = self.db.execute("UPDATE messages SET idx=?, sender=?, subject=?, date_txt=?, ts=? WHERE message_id=?",
                                  (h["idx"], h["from"], h["subject"], h["date"], h.get("ts", 0), h["message_id"]))
            if cur.rowcount == 0:
                self.db.execute("INSERT INTO messages (message_id, idx, sender, subject, date_txt, ts) VALUES (?,?,?,?,?,?)",
                                (h["message_id"], h["idx"], h["from"], h["subject"], h["date"], h.get("ts", 0)))
        self.db.commit()

    def reconcile(self, items):
        """After loading the NEWEST page: forget cached messages inside that time range that the server no longer has."""
        stamps = [h.get("ts", 0) for h in items if h.get("ts", 0) > 0]
        if not stamps:
            return
        seen = [h["message_id"] for h in items]
        low = min(stamps)
        for mid, ts in self.db.execute("SELECT message_id, ts FROM messages WHERE ts >= ?", (low,)).fetchall():
            if mid not in seen:
                self.db.execute("DELETE FROM messages WHERE message_id=?", (mid,))
        self.db.commit()

    def page(self, limit):
        rows = self.db.execute("SELECT idx, sender, subject, date_txt, message_id FROM messages "
                               "ORDER BY ts DESC, idx DESC LIMIT ?", (limit,)).fetchall()
        return [{"idx": r[0], "from": r[1], "subject": r[2], "date": r[3], "message_id": r[4]} for r in rows]

    def count(self):
        return self.db.execute("SELECT COUNT(*) FROM messages").fetchone()[0]

    def prune(self, keep):
        """Keep only the `keep` newest messages."""
        self.db.execute("DELETE FROM messages WHERE message_id NOT IN "
                        "(SELECT message_id FROM messages ORDER BY ts DESC, idx DESC LIMIT ?)", (keep,))
        self.db.commit()

    def delete_message(self, message_id):
        self.db.execute("DELETE FROM messages WHERE message_id=?", (message_id,))
        self.db.commit()

    # ---- message bodies ----
    def get_body(self, message_id):
        r = self.db.execute("SELECT body, atts, sender, to_txt, subject, full_date FROM messages "
                            "WHERE message_id=? AND body IS NOT NULL", (message_id,)).fetchone()
        if not r:
            return None
        return {"body": r[0], "attachments": [a for a in r[1].split(u"\n") if a], "from": r[2], "to": r[3] or u"",
                "subject": r[4], "date": r[5] or u"", "message_id": message_id}

    def set_body(self, message_id, msg):
        self.db.execute("UPDATE messages SET body=?, atts=?, to_txt=?, full_date=?, fetched=? WHERE message_id=?",
                        (msg["body"], u"\n".join(msg["attachments"]), msg["to"], msg["date"], int(time.time()), message_id))
        self.db.commit()

    # ---- outbox ----
    def outbox_add(self, to, subject, body, in_reply_to, error):
        self.db.execute("INSERT INTO outbox (to_addr, subject, body, in_reply_to, created, error) VALUES (?,?,?,?,?,?)",
                        (to, subject, body, in_reply_to, int(time.time()), error))
        self.db.commit()

    def outbox_list(self):
        rows = self.db.execute("SELECT id, to_addr, subject, body, in_reply_to, error FROM outbox ORDER BY id").fetchall()
        return [{"id": r[0], "to": r[1], "subject": r[2], "body": r[3], "in_reply_to": r[4], "error": r[5]} for r in rows]

    def outbox_count(self):
        return self.db.execute("SELECT COUNT(*) FROM outbox").fetchone()[0]

    def outbox_remove(self, oid):
        self.db.execute("DELETE FROM outbox WHERE id=?", (oid,))
        self.db.commit()

    def outbox_set_error(self, oid, error):
        self.db.execute("UPDATE outbox SET error=? WHERE id=?", (error, oid))
        self.db.commit()


def flush_outbox(cfg, store, send):
    """Try to send every queued message with send(cfg, to, subject, body, in_reply_to).
    Stops at the first failure (probably no network). Returns (sent, remaining, last_error)."""
    sent = 0
    error = None
    for m in store.outbox_list():
        try:
            send(cfg, m["to"], m["subject"], m["body"], m["in_reply_to"])
        except Exception, e:
            error = unicode(str(e), "utf-8", "replace")
            store.outbox_set_error(m["id"], error)
            break
        store.outbox_remove(m["id"])
        sent += 1
    return sent, store.outbox_count(), error
