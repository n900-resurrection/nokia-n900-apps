/*
 * libecho: a minimal "echo" protocol for libpurple 2.7 (Pidgin, telepathy-haze).
 *
 * It is the feasibility test of docs/signal-native.md step 0: does the stock Maemo UI (Accounts, Conversations) show a
 * protocol that comes from a third-party libpurple plugin? The account logs in at once, has one contact "echo-bot", and
 * every message sent to it comes back as "Echo: <text>" half a second later. There is no network access.
 */
#define PURPLE_PLUGINS
#include <string.h>
#include <time.h>
#include <glib.h>

#include "account.h"
#include "blist.h"
#include "connection.h"
#include "debug.h"
#include "plugin.h"
#include "prpl.h"
#include "server.h"
#include "status.h"
#include "version.h"

#define ECHO_ID "prpl-echo"
#define ECHO_BOT "echo-bot"

typedef struct {
    PurpleAccount *account;
    char *who;
    char *text;
} EchoReply;

static const char *echo_list_icon(PurpleAccount *account, PurpleBuddy *buddy)
{
    return "echo";
}

static GList *echo_status_types(PurpleAccount *account)
{
    GList *types = NULL;
    types = g_list_append(types, purple_status_type_new_full(PURPLE_STATUS_AVAILABLE, "available", NULL, TRUE, TRUE, FALSE));
    types = g_list_append(types, purple_status_type_new_full(PURPLE_STATUS_OFFLINE, "offline", NULL, TRUE, TRUE, FALSE));
    return types;
}

static void echo_login(PurpleAccount *account)
{
    PurpleConnection *gc = purple_account_get_connection(account);
    PurpleBuddy *buddy = purple_find_buddy(account, ECHO_BOT);

    purple_debug_info(ECHO_ID, "login %s\n", purple_account_get_username(account));
    purple_connection_set_state(gc, PURPLE_CONNECTED);
    if (!buddy) {
        buddy = purple_buddy_new(account, ECHO_BOT, "Echo bot");
        purple_blist_add_buddy(buddy, NULL, NULL, NULL);
    }
    purple_prpl_got_user_status(account, ECHO_BOT, "available", NULL);
}

static void echo_close(PurpleConnection *gc)
{
    purple_debug_info(ECHO_ID, "close\n");
}

static gboolean echo_reply_cb(gpointer data)
{
    EchoReply *r = data;
    PurpleConnection *gc = purple_account_get_connection(r->account);
    if (gc && PURPLE_CONNECTION_IS_CONNECTED(gc)) {
        char *msg = g_strdup_printf("Echo: %s", r->text);
        serv_got_im(gc, r->who, msg, PURPLE_MESSAGE_RECV, time(NULL));
        g_free(msg);
    }
    g_free(r->who);
    g_free(r->text);
    g_free(r);
    return FALSE;
}

static int echo_send_im(PurpleConnection *gc, const char *who, const char *message, PurpleMessageFlags flags)
{
    EchoReply *r = g_new0(EchoReply, 1);
    r->account = purple_connection_get_account(gc);
    r->who = g_strdup(who);
    r->text = g_strdup(message);
    g_timeout_add(500, echo_reply_cb, r);
    return 1;
}

static void echo_add_buddy(PurpleConnection *gc, PurpleBuddy *buddy, PurpleGroup *group)
{
    purple_prpl_got_user_status(purple_connection_get_account(gc), purple_buddy_get_name(buddy), "available", NULL);
}

static PurplePluginProtocolInfo prpl_info;

static PurplePluginInfo info;

static void echo_init_plugin(PurplePlugin *plugin)
{
    memset(&prpl_info, 0, sizeof(prpl_info));
    prpl_info.struct_size = sizeof(prpl_info);
    prpl_info.options = OPT_PROTO_NO_PASSWORD;
    prpl_info.list_icon = echo_list_icon;
    prpl_info.status_types = echo_status_types;
    prpl_info.login = echo_login;
    prpl_info.close = echo_close;
    prpl_info.send_im = echo_send_im;
    prpl_info.add_buddy = echo_add_buddy;

    memset(&info, 0, sizeof(info));
    info.magic = PURPLE_PLUGIN_MAGIC;
    info.major_version = PURPLE_MAJOR_VERSION;
    info.minor_version = PURPLE_MINOR_VERSION;
    info.type = PURPLE_PLUGIN_PROTOCOL;
    info.priority = PURPLE_PRIORITY_DEFAULT;
    info.id = ECHO_ID;
    info.name = "Echo";
    info.version = "0.1";
    info.summary = "Echo test protocol";
    info.description = "Answers every message with \"Echo: <text>\". Test of third-party protocols in the Maemo messaging UI.";
    info.author = "elPytel";
    info.homepage = "https://github.com/n900-resurrection";
    info.extra_info = &prpl_info;
    plugin->info = &info;
}

PURPLE_INIT_PLUGIN(echo, echo_init_plugin, info)
