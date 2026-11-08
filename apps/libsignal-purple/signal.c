/*
 * libsignal: Signal protocol plugin for libpurple 2.7 (Pidgin, telepathy-haze on Maemo 5).
 *
 * The plugin does no Signal cryptography itself. It talks over a unix socket (~/.local/share/signal-bridge/bridge.sock) to
 * the signal-bridge daemon (presage), which owns the linked device. When the socket is not there, the plugin starts the
 * daemon (/opt/signal-bridge/bin/signal-bridge-start) and keeps trying for about two minutes (the daemon needs about
 * 45 s on the N900 to open its encrypted store and connect).
 *
 * Protocol: one line per message, fields separated by TAB, "\\", "\t", "\n" escaped; see apps/signal-bridge/src/main.rs.
 * The account name is free (the phone number is a good choice); the account of signal-bridge is the one linked with gurk.
 */
#define PURPLE_PLUGINS
#include <errno.h>
#include <stdarg.h>
#include <fcntl.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <time.h>
#include <unistd.h>
#include <glib.h>

#include "account.h"
#include "blist.h"
#include "connection.h"
#include "conversation.h"
#include "debug.h"
#include "eventloop.h"
#include "plugin.h"
#include "prpl.h"
#include "server.h"
#include "status.h"
#include "util.h"
#include "version.h"

#define SIGNAL_ID "prpl-signal"
#define DAEMON_START "/opt/signal-bridge/bin/signal-bridge-start"
#define CONNECT_TRIES 40          /* x 3 s */
#define LAST_TS "last-message-ts"  /* account setting: newest message delivered (ms) */

typedef struct {
    PurpleConnection *gc;
    PurpleAccount *account;
    int fd;
    guint input;
    guint retry;
    int tries;
    gboolean spawned;
    GString *buf;
    char *self_uuid;
    GHashTable *contacts;   /* uuid -> NULL */
    GHashTable *pending;    /* send id -> recipient uuid */
    unsigned next_id;
    guint64 last_ts;
    guint64 since_snapshot;  /* last_ts when the history was requested */
    int hist_pending;        /* HISTORY answers still to come */
} Sig;

static guint64 now_ms(void)
{
    return (guint64)time(NULL) * 1000;
}

/* ---- protocol helpers ---------------------------------------------------------------------------------------------- */

static char *esc(const char *s)
{
    GString *o = g_string_new(NULL);
    for (; *s; s++) {
        switch (*s) {
        case '\\': g_string_append(o, "\\\\"); break;
        case '\t': g_string_append(o, "\\t"); break;
        case '\n': g_string_append(o, "\\n"); break;
        case '\r': break;
        default: g_string_append_c(o, *s);
        }
    }
    return g_string_free(o, FALSE);
}

static char *unesc(const char *s)
{
    GString *o = g_string_new(NULL);
    for (; *s; s++) {
        if (*s != '\\' || !s[1]) {
            g_string_append_c(o, *s);
            continue;
        }
        s++;
        switch (*s) {
        case 't': g_string_append_c(o, '\t'); break;
        case 'n': g_string_append_c(o, '\n'); break;
        case '\\': g_string_append_c(o, '\\'); break;
        default: g_string_append_c(o, '\\'); g_string_append_c(o, *s);
        }
    }
    return g_string_free(o, FALSE);
}

/* Send one protocol line made of the given fields (NULL terminated). */
static void send_fields(Sig *s, const char *first, ...)
{
    GString *l = g_string_new(NULL);
    va_list ap;
    const char *f;
    gboolean firstf = TRUE;
    char *e;

    va_start(ap, first);
    for (f = first; f; f = va_arg(ap, const char *)) {
        e = esc(f);
        if (!firstf)
            g_string_append_c(l, '\t');
        g_string_append(l, e);
        g_free(e);
        firstf = FALSE;
    }
    va_end(ap);
    g_string_append_c(l, '\n');
    if (s->fd >= 0 && write(s->fd, l->str, l->len) < 0)
        purple_debug_warning(SIGNAL_ID, "write failed: %s\n", g_strerror(errno));
    g_string_free(l, TRUE);
}

/* Message text for the conversation window: HTML. */
static char *to_html(const char *text)
{
    char *e = g_markup_escape_text(text, -1);
    char *h = purple_strreplace(e, "\n", "<br>");
    g_free(e);
    return h;
}

static void remember_ts(Sig *s, guint64 ts)
{
    char tmp[32];
    if (ts <= s->last_ts)
        return;
    s->last_ts = ts;
    g_snprintf(tmp, sizeof tmp, "%" G_GUINT64_FORMAT, ts);
    purple_account_set_string(s->account, LAST_TS, tmp);
}

/* ---- incoming lines ------------------------------------------------------------------------------------------------ */

static void add_contact(Sig *s, const char *uuid, const char *name, const char *phone)
{
    PurpleBuddy *b = purple_find_buddy(s->account, uuid);
    const char *alias = (name && *name) ? name : (phone && *phone ? phone : NULL);
    char *self_alias = NULL;

    if (!g_hash_table_lookup_extended(s->contacts, uuid, NULL, NULL))
        g_hash_table_insert(s->contacts, g_strdup(uuid), NULL);
    if (s->self_uuid && !strcmp(uuid, s->self_uuid)) {
        self_alias = g_strdup_printf("%s (Note to Self)", alias ? alias : "Me");
        alias = self_alias;
    }
    if (!b) {
        b = purple_buddy_new(s->account, uuid, alias);
        purple_blist_add_buddy(b, NULL, NULL, NULL);
    } else if (alias) {
        purple_blist_alias_buddy(b, alias);
    }
    purple_prpl_got_user_status(s->account, uuid, "available", NULL);
    g_free(self_alias);
}

static void show_message(Sig *s, const char *uuid, guint64 ts, const char *text, gboolean outgoing)
{
    char *html = to_html(text);

    if (outgoing) {
        /* written on another device of ours (or Note to Self): show it as sent by us */
        PurpleConversation *conv = purple_find_conversation_with_account(PURPLE_CONV_TYPE_IM, uuid, s->account);
        if (!conv)
            conv = purple_conversation_new(PURPLE_CONV_TYPE_IM, s->account, uuid);
        purple_conv_im_write(PURPLE_CONV_IM(conv), uuid, html, PURPLE_MESSAGE_SEND, (time_t)(ts / 1000));
    } else {
        serv_got_im(s->gc, uuid, html, PURPLE_MESSAGE_RECV, (time_t)(ts / 1000));
    }
    remember_ts(s, ts);
    g_free(html);
}

static void handle_line(Sig *s, char **f, int n)
{
    const char *cmd = f[0];

    if (!strcmp(cmd, "READY") && n >= 2) {
        g_free(s->self_uuid);
        s->self_uuid = g_strdup(f[1]);
        purple_connection_set_state(s->gc, PURPLE_CONNECTED);
        if (!s->last_ts) {
            remember_ts(s, now_ms());   /* first login: only messages from now on */
        }
        send_fields(s, "CONTACTS", NULL);
    } else if (!strcmp(cmd, "CONTACT") && n >= 3) {
        add_contact(s, f[1], f[2], n >= 4 ? f[3] : NULL);
    } else if (!strcmp(cmd, "CONTACTS-END")) {
        /* messages that arrived while we were not connected */
        GHashTableIter it;
        gpointer k;
        char since[32];
        s->since_snapshot = s->last_ts;
        g_snprintf(since, sizeof since, "%" G_GUINT64_FORMAT, s->last_ts);
        g_hash_table_iter_init(&it, s->contacts);
        while (g_hash_table_iter_next(&it, &k, NULL)) {
            send_fields(s, "HISTORY", "h", (const char *)k, since, NULL);
            s->hist_pending++;
        }
    } else if (!strcmp(cmd, "MSG") && n >= 4) {
        guint64 ts = g_ascii_strtoull(f[2], NULL, 10);
        if (s->self_uuid && !strcmp(f[1], s->self_uuid))
            return;            /* our own message, sent through the bridge: already in the window */
        if (s->hist_pending > 0 && ts <= s->since_snapshot)
            return;            /* already shown in an earlier session */
        show_message(s, f[1], ts, f[3], FALSE);
    } else if (!strcmp(cmd, "SENT") && n >= 4) {
        guint64 ts = g_ascii_strtoull(f[2], NULL, 10);
        if (s->hist_pending > 0 && ts <= s->since_snapshot)
            return;
        show_message(s, f[1], ts, f[3], TRUE);
    } else if (!strcmp(cmd, "OK") && n >= 2) {
        g_hash_table_remove(s->pending, f[1]);
    } else if (!strcmp(cmd, "ERR") && n >= 3) {
        const char *who = g_hash_table_lookup(s->pending, f[1]);
        char *msg = g_strdup_printf("Message not sent: %s", f[2]);
        if (who)
            purple_conv_present_error(who, s->account, msg);
        else
            purple_debug_warning(SIGNAL_ID, "bridge error: %s\n", f[2]);
        g_hash_table_remove(s->pending, f[1]);
        g_free(msg);
    } else if (!strcmp(cmd, "HISTORY-END")) {
        if (s->hist_pending > 0)
            s->hist_pending--;
    }
    /* GMSG, GSENT, GROUP, CONTACTS-CHANGED, PONG: not used yet */
}

static void parse_buffer(Sig *s)
{
    char *nl;
    while ((nl = memchr(s->buf->str, '\n', s->buf->len)) != NULL) {
        char *l = g_strndup(s->buf->str, nl - s->buf->str);
        char **raw = g_strsplit(l, "\t", -1);
        int n = g_strv_length(raw), i;
        char **f = g_new0(char *, n + 1);
        for (i = 0; i < n; i++)
            f[i] = unesc(raw[i]);
        if (n > 0)
            handle_line(s, f, n);
        g_strfreev(f);
        g_strfreev(raw);
        g_free(l);
        g_string_erase(s->buf, 0, (nl - s->buf->str) + 1);
    }
}

static void on_input(gpointer data, gint fd, PurpleInputCondition cond)
{
    Sig *s = data;
    char chunk[4096];
    ssize_t r = recv(fd, chunk, sizeof chunk, MSG_DONTWAIT);

    if (r > 0) {
        g_string_append_len(s->buf, chunk, r);
        parse_buffer(s);
    } else if (r == 0 || (errno != EAGAIN && errno != EINTR)) {
        PurpleConnection *gc = s->gc;
        purple_input_remove(s->input);
        s->input = 0;
        close(s->fd);
        s->fd = -1;
        purple_connection_error_reason(gc, PURPLE_CONNECTION_ERROR_NETWORK_ERROR, "The signal-bridge daemon closed the connection");
    }
}

/* ---- connecting ---------------------------------------------------------------------------------------------------- */

static char *socket_path(void)
{
    return g_build_filename(g_get_home_dir(), ".local", "share", "signal-bridge", "bridge.sock", NULL);
}

static gboolean try_connect(Sig *s)
{
    struct sockaddr_un a;
    char *path = socket_path();
    int fd = socket(AF_UNIX, SOCK_STREAM, 0);

    memset(&a, 0, sizeof a);
    a.sun_family = AF_UNIX;
    g_strlcpy(a.sun_path, path, sizeof a.sun_path);
    g_free(path);
    if (fd < 0)
        return FALSE;
    if (connect(fd, (struct sockaddr *)&a, sizeof a) != 0) {
        close(fd);
        return FALSE;
    }
    fcntl(fd, F_SETFD, FD_CLOEXEC);
    s->fd = fd;
    s->input = purple_input_add(fd, PURPLE_INPUT_READ, on_input, s);
    return TRUE;
}

static gboolean retry_cb(gpointer data)
{
    Sig *s = data;

    if (try_connect(s)) {
        s->retry = 0;
        purple_connection_update_progress(s->gc, "Waiting for Signal", 2, 3);
        return FALSE;
    }
    if (++s->tries >= CONNECT_TRIES) {
        s->retry = 0;
        purple_connection_error_reason(s->gc, PURPLE_CONNECTION_ERROR_NETWORK_ERROR,
                                       "signal-bridge did not start (see ~/.local/share/signal-bridge/daemon.log)");
        return FALSE;
    }
    return TRUE;
}

static void spawn_daemon(Sig *s)
{
    char *argv[] = { DAEMON_START, NULL };
    GError *err = NULL;

    if (!g_spawn_async(NULL, argv, NULL, G_SPAWN_STDOUT_TO_DEV_NULL | G_SPAWN_STDERR_TO_DEV_NULL,
                       NULL, NULL, NULL, &err)) {
        purple_debug_warning(SIGNAL_ID, "cannot start the daemon: %s\n", err->message);
        g_error_free(err);
    }
    s->spawned = TRUE;
}

/* ---- the protocol -------------------------------------------------------------------------------------------------- */

static const char *signal_list_icon(PurpleAccount *account, PurpleBuddy *buddy)
{
    return "signal";
}

static GList *signal_status_types(PurpleAccount *account)
{
    GList *types = NULL;
    types = g_list_append(types, purple_status_type_new_full(PURPLE_STATUS_AVAILABLE, "available", NULL, TRUE, TRUE, FALSE));
    types = g_list_append(types, purple_status_type_new_full(PURPLE_STATUS_OFFLINE, "offline", NULL, TRUE, TRUE, FALSE));
    return types;
}

static void signal_login(PurpleAccount *account)
{
    PurpleConnection *gc = purple_account_get_connection(account);
    Sig *s = g_new0(Sig, 1);

    s->gc = gc;
    s->account = account;
    s->fd = -1;
    s->buf = g_string_new(NULL);
    s->contacts = g_hash_table_new_full(g_str_hash, g_str_equal, g_free, NULL);
    s->pending = g_hash_table_new_full(g_str_hash, g_str_equal, g_free, g_free);
    s->last_ts = g_ascii_strtoull(purple_account_get_string(account, LAST_TS, "0"), NULL, 10);
    gc->proto_data = s;
    purple_connection_update_progress(gc, "Connecting to signal-bridge", 0, 3);

    if (try_connect(s)) {
        purple_connection_update_progress(gc, "Waiting for Signal", 2, 3);
        return;
    }
    purple_connection_update_progress(gc, "Starting signal-bridge", 1, 3);
    spawn_daemon(s);
    s->retry = purple_timeout_add(3000, retry_cb, s);
}

static void signal_close(PurpleConnection *gc)
{
    Sig *s = gc->proto_data;

    if (!s)
        return;
    if (s->retry)
        purple_timeout_remove(s->retry);
    if (s->input)
        purple_input_remove(s->input);
    if (s->fd >= 0)
        close(s->fd);
    g_string_free(s->buf, TRUE);
    g_hash_table_destroy(s->contacts);
    g_hash_table_destroy(s->pending);
    g_free(s->self_uuid);
    g_free(s);
    gc->proto_data = NULL;
}

static int signal_send_im(PurpleConnection *gc, const char *who, const char *message, PurpleMessageFlags flags)
{
    Sig *s = gc->proto_data;
    char *plain, id[16];

    if (!s || s->fd < 0)
        return -ENOTCONN;
    plain = purple_markup_strip_html(message);
    g_snprintf(id, sizeof id, "s%u", ++s->next_id);
    g_hash_table_insert(s->pending, g_strdup(id), g_strdup(who));
    send_fields(s, "SEND", id, who, plain, NULL);
    g_free(plain);
    return 1;
}

static void signal_add_buddy(PurpleConnection *gc, PurpleBuddy *buddy, PurpleGroup *group)
{
    purple_prpl_got_user_status(purple_connection_get_account(gc), purple_buddy_get_name(buddy), "available", NULL);
}

static PurplePluginProtocolInfo prpl_info;
static PurplePluginInfo info;

static void signal_init_plugin(PurplePlugin *plugin)
{
    memset(&prpl_info, 0, sizeof(prpl_info));
    prpl_info.struct_size = sizeof(prpl_info);
    prpl_info.options = OPT_PROTO_NO_PASSWORD;
    prpl_info.list_icon = signal_list_icon;
    prpl_info.status_types = signal_status_types;
    prpl_info.login = signal_login;
    prpl_info.close = signal_close;
    prpl_info.send_im = signal_send_im;
    prpl_info.add_buddy = signal_add_buddy;

    memset(&info, 0, sizeof(info));
    info.magic = PURPLE_PLUGIN_MAGIC;
    info.major_version = PURPLE_MAJOR_VERSION;
    info.minor_version = PURPLE_MINOR_VERSION;
    info.type = PURPLE_PLUGIN_PROTOCOL;
    info.priority = PURPLE_PRIORITY_DEFAULT;
    info.id = SIGNAL_ID;
    info.name = "Signal";
    info.version = "0.1";
    info.summary = "Signal through signal-bridge";
    info.description = "Signal messages through the local signal-bridge daemon (presage).";
    info.author = "elPytel";
    info.homepage = "https://github.com/n900-resurrection";
    info.extra_info = &prpl_info;
    plugin->info = &info;
}

PURPLE_INIT_PLUGIN(signal, signal_init_plugin, info)
