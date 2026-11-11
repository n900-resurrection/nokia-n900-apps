/* Smoke test for the static GLib 2.66 build: prints one line per check, "ok" or "FAIL". */
#include <gio/gio.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

static int fails;
static void check(const char *name, int ok) { printf("%s %s\n", ok ? "ok  " : "FAIL", name); if (!ok) fails++; }

static gboolean quit_cb(gpointer loop) { g_main_loop_quit(loop); return G_SOURCE_REMOVE; }

int main(void)
{
    printf("glib %u.%u.%u\n", glib_major_version, glib_minor_version, glib_micro_version);
    check("version 2.66", glib_major_version == 2 && glib_minor_version == 66);

    GHashTable *h = g_hash_table_new_full(g_str_hash, g_str_equal, g_free, NULL);
    g_hash_table_insert(h, g_strdup("a"), GINT_TO_POINTER(1));
    check("hash table", GPOINTER_TO_INT(g_hash_table_lookup(h, "a")) == 1);
    g_hash_table_destroy(h);

    GError *err = NULL;
    GRegex *re = g_regex_new("(\\w+)@(\\w+)\\.cz", 0, 0, &err);
    GMatchInfo *mi = NULL;
    check("regex (bundled pcre)", re && g_regex_match(re, "mail jan@example.cz now", 0, &mi) && mi);
    if (mi) { gchar *w = g_match_info_fetch(mi, 2); check("regex group", w && !strcmp(w, "example")); g_free(w); g_match_info_free(mi); }
    if (re) g_regex_unref(re);

    GKeyFile *kf = g_key_file_new();
    check("keyfile", g_key_file_load_from_data(kf, "[a]\nb=42\n", -1, 0, NULL) && g_key_file_get_integer(kf, "a", "b", NULL) == 42);
    g_key_file_free(kf);

    gchar *u = g_uuid_string_random();
    check("uuid", u && strlen(u) == 36);
    g_free(u);

    GDateTime *dt = g_date_time_new_utc(2026, 11, 11, 19, 0, 0);
    gchar *iso = dt ? g_date_time_format_iso8601(dt) : NULL;
    check("datetime", iso && !strcmp(iso, "2026-11-11T19:00:00Z"));
    g_free(iso); if (dt) g_date_time_unref(dt);

    gchar *utf = g_utf8_strup("ahoj čeština", -1);
    check("utf8 upper", utf && !strcmp(utf, "AHOJ ČEŠTINA"));
    g_free(utf);

    gchar *tmpl = g_strdup("/tmp/glibtestXXXXXX");
    int fd = g_mkstemp(tmpl); close(fd);
    check("file set/get contents", g_file_set_contents(tmpl, "hello", 5, NULL));
    gchar *content = NULL; gsize len = 0;
    check("file contents round trip", g_file_get_contents(tmpl, &content, &len, NULL) && len == 5 && !memcmp(content, "hello", 5));
    g_free(content);
    GFile *f = g_file_new_for_path(tmpl);
    GFileInfo *info = g_file_query_info(f, "standard::size", 0, NULL, NULL);
    check("gio query_info", info && g_file_info_get_size(info) == 5);
    if (info) g_object_unref(info);
    check("gio delete", g_file_delete(f, NULL, NULL));
    g_object_unref(f); g_free(tmpl);

    GMainLoop *loop = g_main_loop_new(NULL, FALSE);
    g_timeout_add(50, quit_cb, loop);
    g_main_loop_run(loop);
    check("main loop timeout", 1);
    g_main_loop_unref(loop);

    GInetAddress *ia = g_inet_address_new_from_string("192.168.1.10");
    gchar *s = ia ? g_inet_address_to_string(ia) : NULL;
    check("gio inet address", s && !strcmp(s, "192.168.1.10"));
    g_free(s); if (ia) g_object_unref(ia);

    GThread *t = NULL;
    check("thread-safe init", (t = g_thread_try_new("x", (GThreadFunc)g_get_user_name, NULL, NULL)) != NULL);
    if (t) g_thread_join(t);

    printf("%s\n", fails ? "FAILED" : "ALL OK");
    return fails != 0;
}
