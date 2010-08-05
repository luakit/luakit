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

#include <gtk/gtk.h>
#include <signal.h>
#include <stdlib.h>
#include <sys/wait.h>
#include "globalconf.h"
#include "common/util.h"
#include "luah.h"
#include "luakit.h"

static void sigchld(int sigint);

void
sigchld(int signum) {
    (void) signum;
    if (signal(SIGCHLD, sigchld) == SIG_ERR)
        fatal("Can't install SIGCHLD handler");
    while(0 < waitpid(-1, NULL, WNOHANG));
}

/* load command line options into luakit and return uris to load */
gchar**
parseopts(int argc, char *argv[]) {
    GOptionContext *context;
    gboolean *only_version = NULL;
    gchar **uris = NULL;

    /* define command line options */
    const GOptionEntry entries[] = {
        { "uri", 'u', 0, G_OPTION_ARG_STRING_ARRAY, &uris,
            "uri(s) to load at startup", "URI" },
        { "config", 'c', 0, G_OPTION_ARG_STRING, &globalconf.confpath,
            "configuration file to use", "FILE" },
        { "version", 'V', 0, G_OPTION_ARG_NONE, &only_version,
            "show version", NULL },
        { NULL, 0, 0, 0, NULL, NULL, NULL }};

    /* parse command line options */
    context = g_option_context_new("[URI...]");
    g_option_context_add_main_entries(context, entries, NULL);
    g_option_context_add_group(context, gtk_get_option_group(TRUE));
    // TODO Passing gtk options (like --sync) to luakit causes a segfault right
    // here. I'm clueless.
    g_option_context_parse(context, &argc, &argv, NULL);
    g_option_context_free(context);

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

void
init_lua(gchar **uris)
{
    gchar *uri;
    lua_State *L;
    xdgHandle xdg;

    /* init globalconf structs */
    globalconf.signals = signal_tree_new();
    globalconf.windows = g_ptr_array_new();

    /* get XDG basedir data */
    xdgInitHandle(&xdg);

    /* init lua */
    luaH_init(&xdg);
    L = globalconf.L;

    /* push a table of the statup uris */
    lua_newtable(L);
    for (gint i = 0; (uri = uris[i]); i++) {
        lua_pushstring(L, uri);
        lua_rawseti(L, -2, i + 1);
    }
    lua_setglobal(L, "uris");

    /* parse and run configuration file */
    if(!luaH_parserc(&xdg, globalconf.confpath, TRUE))
        fatal("couldn't find rc file");

    if (!globalconf.windows->len)
        fatal("no windows spawned by rc file load, exiting");

    /* we are finished with this */
    xdgWipeHandle(&xdg);
}

void
init_directories()
{
    /* create luakit directory */
    globalconf.base_directory = g_build_filename(g_get_home_dir(), LUAKIT_CONFIG_DIR, NULL);
    g_mkdir_with_parents(globalconf.base_directory, 0771);
}

int
main(int argc, char *argv[]) {
    gchar **uris = NULL;

    /* clean up any zombies */
    sigchld(0);

    gtk_init(&argc, &argv);
    if (!g_thread_supported())
        g_thread_init(NULL);

    /* parse command line opts and get uris to load */
    uris = parseopts(argc, argv);

    init_directories();
    init_lua(uris);
    gtk_main();
    return EXIT_SUCCESS;
}

// vim: ft=c:et:sw=4:ts=8:sts=4:enc=utf-8:tw=80
