/*
 * luakit.c - luakit main functions
 *
 * Copyright (C) 2010 Mason Larobina <mason.larobina@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

/*
 * MIT/X Consortium License (applies to some functions from surf.c)
 *
 * (C) 2009 Enno Boland <gottox@s01.de>
 *
 * See COPYING.MIT for the full license.
 *
 */

#include "luakit.h"
#include "util.h"
#include "luafuncs.h"

Luakit luakit;

static void destroy_win(GtkWidget *w, ...);
static void setup_win(void);
static void sigchld(int sigint);

/* destroys a status bar */
void
destroy_sbar(Statusbar *s) {
    GPtrArray *sbars = luakit.sbars;

    debug("Destroying status bar at %p, total %d", (gpointer) s, sbars->len-1);
    gtk_widget_destroy(GTK_WIDGET(s->label));
    gtk_widget_destroy(GTK_WIDGET(s->hbox));
    g_ptr_array_remove(sbars, (gpointer) s);
    free(s);
    s = NULL;
}

/* destroys a webkit webview */
void
destroy_view(View *v) {
    GPtrArray *views = luakit.views;

    debug("Destroying view at %p, total %d", (gpointer) v, views->len-1);
    gtk_widget_destroy(GTK_WIDGET(v->scroll));
    g_ptr_array_remove(views, (gpointer) v);
    free(v);
    v = NULL;

    /* exit if there are no more views */
    if(!views->len)
        destroy();
}

/* destroys the root window and all children */
void
destroy(void) {
    Luakit *l = &luakit;
    GPtrArray *views = l->views;
    GPtrArray *sbars = l->sbars;

    /* destroy all webkit webviews */
    if (views) {
        while(views->len)
            destroy_view((View*) views->pdata[views->len-1]);
        g_ptr_array_free(views, FALSE);
        views = NULL;
    }

    /* destroy all status bars */
    if (sbars) {
        while(sbars->len)
            destroy_sbar((Statusbar*) sbars->pdata[sbars->len-1]);
        g_ptr_array_free(sbars, FALSE);
        sbars = NULL;
    }

    /* destroy main gtk widgets */
    if(l->nbook) { gtk_widget_destroy(GTK_WIDGET(l->nbook)); l->nbook = NULL; }
    if(l->vbox) { gtk_widget_destroy(GTK_WIDGET(l->vbox)); l->vbox = NULL; }
    if(l->win) { gtk_widget_destroy(GTK_WIDGET(l->win)); l->win = NULL; }

    /* quit gracefully */
    if(gtk_main_level())
        gtk_main_quit();
    else
        exit(luakit.retval);
}

void
destroy_win(GtkWidget *w, ...) {
    (void) w;
    destroy();
}

/* creates new status bar */
Statusbar*
new_sbar(void) {
    Statusbar *s;
    Luakit *l = &luakit;

    /* allocate memory for the status bar */
    if(!(s = calloc(1, sizeof(Statusbar))))
        fatal("Cannot malloc!\n");

    /* create status bar */
    s->label = gtk_label_new("GtkLabel");
    gtk_label_set_selectable((GtkLabel *)s->label, TRUE);
    gtk_label_set_ellipsize(GTK_LABEL(s->label), PANGO_ELLIPSIZE_END);
    gtk_misc_set_alignment(GTK_MISC(s->label), 0, 0);
    gtk_misc_set_padding(GTK_MISC(s->label), 2, 2);

    /* wrap in a hbox to catch widget events */
    s->hbox = gtk_hbox_new(FALSE, 0);
    gtk_box_pack_start(GTK_BOX(s->hbox), GTK_WIDGET(s->label), TRUE, TRUE, 0);

    gtk_widget_show(s->label);
    gtk_widget_show(s->hbox);
    g_ptr_array_add(l->sbars, (gpointer) s);

    /* TODO: Add the ability to define the placement, order and visibility of
     * the statusbar and move the following line elsewhere. */
    gtk_box_pack_start(GTK_BOX(l->vbox), s->hbox, FALSE, TRUE, 0);

    debug("New status bar at %p, total %d", s, luakit.sbars->len);
    return s;
}

/* creates new webkit webview */
View*
new_view(void) {
    Luakit *l = &luakit;
    View *v;

    /* allocate memory for the view */
    if(!(v = calloc(1, sizeof(View))))
        fatal("Cannot malloc!\n");

    v->title = NULL;

    /* webkit webview */
    v->view = WEBKIT_WEB_VIEW(webkit_web_view_new());

    /* create scrolled window */
    v->scroll = gtk_scrolled_window_new(NULL, NULL);
    gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(v->scroll),
        GTK_POLICY_NEVER, GTK_POLICY_NEVER);
    gtk_container_add(GTK_CONTAINER(v->scroll), GTK_WIDGET(v->view));

    /* setup */
    gtk_widget_show(GTK_WIDGET(v->view));
    gtk_widget_show(v->scroll);
    g_ptr_array_add(l->views, (gpointer) v);
    webkit_web_view_set_full_content_zoom(v->view, TRUE);
    /* TODO: Add the ability to change the order in which the new view is
     * added into the notebook (i.e. at the end, after the current). */
    gtk_notebook_append_page(GTK_NOTEBOOK(l->nbook), v->scroll, NULL);

    debug("New view at %p, total %d", v, luakit.views->len);
    return v;
}

void
load_uri(View *v, gchar *uri) {
    gchar *u;

    u = g_strrstr(uri, "://") ? g_strdup(uri)
        : g_strdup_printf("http://%s", uri);
    webkit_web_view_load_uri(v->view, u);
    v->progress = 0;
    if (v->title) g_free(v->title);
    v->title = g_strdup(u);
    debug("Navigating view at %p to %s", v, u);
}

/* setups the root gtk window */
void
setup_win(void) {
    Luakit *l = &luakit;

    /* create window */
    l->win = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    gtk_window_set_wmclass(GTK_WINDOW(l->win), "luakit", "luakit");
    gtk_window_set_default_size(GTK_WINDOW(l->win), 800, 600);
    g_signal_connect(G_OBJECT(l->win), "destroy", G_CALLBACK(destroy_win), NULL);

    /* create notebook */
    l->nbook = gtk_notebook_new();
    gtk_notebook_set_show_border(GTK_NOTEBOOK(l->nbook), FALSE);
    gtk_notebook_set_scrollable(GTK_NOTEBOOK(l->nbook), TRUE);

    /* arranging */
    l->vbox = gtk_vbox_new(FALSE, 0);
    gtk_box_pack_start(GTK_BOX(l->vbox), l->nbook, TRUE, TRUE, 0);
    gtk_container_add(GTK_CONTAINER(l->win), GTK_WIDGET(l->vbox));

    /* show widgets */
    gtk_widget_show(GTK_WIDGET(l->nbook));
    gtk_widget_show(GTK_WIDGET(l->vbox));
    gtk_widget_show(GTK_WIDGET(l->win));
}

void
sigchld(int signum) {
    (void) signum;
    if (signal(SIGCHLD, sigchld) == SIG_ERR)
        fatal("Can't install SIGCHLD handler");
    while(0 < waitpid(-1, NULL, WNOHANG));
}

/* init application */
void
init(int argc, char *argv[]) {
    Luakit *l = &luakit;
    l->retval = EXIT_SUCCESS;

    /* clean up any zombies immediately */
    sigchld(0);
    gtk_init(&argc, &argv);
    if (!g_thread_supported())
        g_thread_init(NULL);

    /* init luakit struct */
    l->execpath = g_strdup(argv[0]);
    l->views = g_ptr_array_new();
    l->sbars = g_ptr_array_new();
}

/* load command line options into luakit and return uris to load */
gchar**
parseopts(int argc, char *argv[]) {
    GError *err = NULL;
    GOptionContext *context;
    Luakit *l = &luakit;
    gboolean *only_version = NULL;
    gchar **uris = NULL;

    /* define command line options */
    const GOptionEntry entries[] = {
        { "uri", 'u', 0, G_OPTION_ARG_STRING_ARRAY, &uris,
            "uri(s) to load at startup", "URI" },
        { "config", 'c', 0, G_OPTION_ARG_STRING, &l->confpath,
            "configuration file to use", "FILE" },
        { "version", 'V', 0, G_OPTION_ARG_NONE, &only_version,
            "show version", NULL },
        { NULL, 0, 0, 0, NULL, NULL, NULL }};

    /* parse command line options */
    context = g_option_context_new("[URI...]");
    g_option_context_add_main_entries(context, entries, NULL);
    g_option_context_add_group(context, gtk_get_option_group(TRUE));
    if(!g_option_context_parse(context, &argc, &argv, &err))
        fatal("option parsing failed: %s\n", err->message);
    g_option_context_free(context);
    if(err) g_error_free(err);

    /* print version and exit */
    if(only_version) {
        g_printf("Version: %s\n", VERSION);
        exit(EXIT_SUCCESS);
    }

    if (uris && argv[1])
        fatal("invalid mix of -u and default uri arguments");

    if (uris)
        return uris;
    else
        return argv+1;
}

int
main(int argc, char *argv[]) {
    Luakit *l = &luakit;
    gchar **uris = NULL;
    View *v;
    xdgHandle xdg;

    /* init app */
    init(argc, argv);

    /* parse command line opts and get uris to load */
    uris = parseopts(argc, argv);

    /* get XDG basedir data */
    xdgInitHandle(&xdg);

    /* init lua */
    luaH_init(&xdg);

    /* parse and run configuration file */
    if(!luaH_parserc(&xdg, l->confpath, TRUE))
        fatal("couldn't find any rc file");

    /* we are finished with this */
    xdgWipeHandle(&xdg);

    /* setup the root window */
    setup_win();

    /* load startup uris */
    while (*uris) {
        v = new_view();
        load_uri(v, *uris++);
    }

    if(!l->views->len)
        new_view();

    new_sbar();

    /* enter main gtk loop */
    gtk_main();

    /* delete all gtk widgets, free memory and exit */
    destroy();

    return EXIT_SUCCESS;
}

// vim: ft=c:et:sw=4:ts=8:sts=4:enc=utf-8:tw=80
