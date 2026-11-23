/* puzzles: a finger-sized list of Simon Tatham's puzzles for the Maemo 5 menu (one menu entry instead of forty).
 * It reads /opt/sgt-puzzles/share/puzzles.list (lines "name|Title|description", made by the build from the .desktop files of the puzzles)
 * and starts /opt/sgt-puzzles/bin/sgt-<name> when a button is tapped. GTK 2 and Hildon. */
#include <gtk/gtk.h>
#include <hildon/hildon.h>
#include <stdio.h>
#include <string.h>

#define PREFIX "/opt/sgt-puzzles"

static void start(GtkWidget *button, gpointer name) {
    gchar *argv[2];
    GError *err = NULL;
    (void)button;
    argv[0] = g_strdup_printf(PREFIX "/bin/sgt-%s", (const char *)name);
    argv[1] = NULL;
    if (!g_spawn_async(NULL, argv, NULL, G_SPAWN_DO_NOT_REAP_CHILD | G_SPAWN_STDOUT_TO_DEV_NULL | G_SPAWN_STDERR_TO_DEV_NULL, NULL, NULL, NULL, &err)) {
        hildon_banner_show_information(NULL, NULL, err->message);
        g_error_free(err);
    }
    g_free(argv[0]);
}

int main(int argc, char **argv) {
    const char *list = argc > 1 ? argv[1] : PREFIX "/share/puzzles.list";
    FILE *f;
    char line[512];
    int n = 0;

    gtk_init(&argc, &argv);
    g_set_application_name("Puzzles");
    HildonProgram *program = hildon_program_get_instance();
    GtkWidget *win = hildon_window_new();
    hildon_program_add_window(program, HILDON_WINDOW(win));
    gtk_window_set_title(GTK_WINDOW(win), "Puzzles");
    g_signal_connect(win, "destroy", G_CALLBACK(gtk_main_quit), NULL);

    GtkWidget *table = gtk_table_new(1, 2, TRUE);
    gtk_table_set_row_spacings(GTK_TABLE(table), 4);
    gtk_table_set_col_spacings(GTK_TABLE(table), 4);
    f = fopen(list, "r");
    if (!f) { g_printerr("puzzles: cannot read %s\n", list); return 1; }
    while (fgets(line, sizeof line, f)) {
        char *name = line, *title, *desc;
        line[strcspn(line, "\r\n")] = 0;
        if (!(title = strchr(name, '|'))) continue;
        *title++ = 0;
        if (!(desc = strchr(title, '|'))) continue;
        *desc++ = 0;
        gchar *markup = g_markup_printf_escaped("<b>%s</b>\n<small>%s</small>", title, desc);
        GtkWidget *b = hildon_gtk_button_new(HILDON_SIZE_FINGER_HEIGHT | HILDON_SIZE_AUTO_WIDTH);
        GtkWidget *label = gtk_label_new(NULL);
        gtk_label_set_markup(GTK_LABEL(label), markup);
        gtk_label_set_justify(GTK_LABEL(label), GTK_JUSTIFY_CENTER);
        gtk_container_add(GTK_CONTAINER(b), label);
        g_free(markup);
        g_signal_connect(b, "clicked", G_CALLBACK(start), g_strdup(name));
        gtk_table_resize(GTK_TABLE(table), n / 2 + 1, 2);
        gtk_table_attach_defaults(GTK_TABLE(table), b, n % 2, n % 2 + 1, n / 2, n / 2 + 1);
        n++;
    }
    fclose(f);
    if (!n) { g_printerr("puzzles: no puzzles in %s\n", list); return 1; }

    GtkWidget *pan = hildon_pannable_area_new();
    hildon_pannable_area_add_with_viewport(HILDON_PANNABLE_AREA(pan), table);
    gtk_container_add(GTK_CONTAINER(win), pan);
    gtk_widget_show_all(win);
    gtk_main();
    return 0;
}
