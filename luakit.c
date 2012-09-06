/*
 * luakit.c - luakit main functions
 *
 * Copyright © 2010-2011 Mason Larobina <mason.larobina@gmail.com>
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

#include "globalconf.h"
#include "common/util.h"
#include "luah.h"

#include <gtk/gtk.h>
#include <signal.h>
#include <stdlib.h>
#include <sys/wait.h>
#include <unistd.h>
#include <errno.h>
#include <locale.h>

static void sigchld(int sigint);

void
sigchld(int UNUSED(signum)) {
    while(0 < waitpid(-1, NULL, WNOHANG));
}

void
init_lua(gchar **uris)
{
    gchar *uri;
    lua_State *L;

    /* init globalconf structs */
    globalconf.windows = g_ptr_array_new();

    /* init lua */
    luaH_init();
    L = globalconf.L;

    /* push a table of the statup uris */
    lua_newtable(L);
    for (gint i = 0; uris && (uri = uris[i]); i++) {
        lua_pushstring(L, uri);
        lua_rawseti(L, -2, i + 1);
    }
    lua_setglobal(L, "uris");
}

void
init_directories(void)
{
    /* create luakit directory */
    globalconf.cache_dir  = g_build_filename(g_get_user_cache_dir(),  "luakit", NULL);
    globalconf.config_dir = g_build_filename(g_get_user_config_dir(), "luakit", NULL);
    globalconf.data_dir   = g_build_filename(g_get_user_data_dir(),   "luakit", NULL);
    g_mkdir_with_parents(globalconf.cache_dir,  0771);
    g_mkdir_with_parents(globalconf.config_dir, 0771);
    g_mkdir_with_parents(globalconf.data_dir,   0771);
}

/* load command line options into luakit and return uris to load */
gchar**
parseopts(int *argc, gchar *argv[], gboolean **nonblock) {
    GOptionContext *context;
    gboolean *version_only = NULL;
    gboolean *check_only = NULL;
    gchar **uris = NULL;

    /* save luakit exec path */
    globalconf.execpath = g_strdup(argv[0]);
    globalconf.nounique = FALSE;

    /* define command line options */
    const GOptionEntry entries[] = {
      { "check",    'k', 0, G_OPTION_ARG_NONE,         &check_only,          "check config and exit",     NULL   },
      { "config",   'c', 0, G_OPTION_ARG_STRING,       &globalconf.confpath, "configuration file to use", "FILE" },
      { "nonblock", 'n', 0, G_OPTION_ARG_NONE,         nonblock,             "run in background",         NULL   },
      { "nounique", 'U', 0, G_OPTION_ARG_NONE,         &globalconf.nounique, "ignore libunique bindings", NULL   },
      { "uri",      'u', 0, G_OPTION_ARG_STRING_ARRAY, &uris,                "uri(s) to load at startup", "URI"  },
      { "verbose",  'v', 0, G_OPTION_ARG_NONE,         &globalconf.verbose,  "print debugging output",    NULL   },
      { "version",  'V', 0, G_OPTION_ARG_NONE,         &version_only,        "print version and exit",    NULL   },
      { NULL,       0,   0, 0,                         NULL,                 NULL,                        NULL   },
    };

    /* parse command line options */
    context = g_option_context_new("[URI...]");
    g_option_context_add_main_entries(context, entries, NULL);
    g_option_context_add_group(context, gtk_get_option_group(FALSE));
    g_option_context_parse(context, argc, &argv, NULL);
    g_option_context_free(context);

    /* print version and exit */
    if (version_only) {
        g_printf("luakit %s\n", VERSION);
        exit(EXIT_SUCCESS);
    }

    /* check config syntax and exit */
    if (check_only) {
        init_directories();
        init_lua(NULL);
        if (!luaH_parserc(globalconf.confpath, FALSE)) {
            g_fprintf(stderr, "Confiuration file syntax error.\n");
            exit(EXIT_FAILURE);
        } else {
            g_fprintf(stderr, "Configuration file syntax OK.\n");
            exit(EXIT_SUCCESS);
        }
    }

    if (uris && argv[1])
        fatal("invalid mix of -u and default uri arguments");

    if (uris)
        return uris;
    else
        return argv+1;
}

gint
main(gint argc, gchar *argv[]) {
    gboolean *nonblock = NULL;
    gchar **uris = NULL;
    pid_t pid, sid;

    globalconf.starttime = l_time();

    /* clean up any zombies */
    struct sigaction sigact;
    sigact.sa_handler=sigchld;
    sigemptyset (&sigact.sa_mask);
    sigact.sa_flags = SA_NOCLDSTOP;
    if (sigaction(SIGCHLD, &sigact, NULL))
        fatal("Can't install SIGCHLD handler");

    /* set numeric locale to C (required for compatibility with
       LuaJIT and luakit scripts) */
    gtk_set_locale();
    gtk_disable_setlocale();
    setlocale(LC_NUMERIC, "C");

    /* parse command line opts and get uris to load */
    uris = parseopts(&argc, argv, &nonblock);

    /* if non block mode - respawn, detach and continue in child */
    if (nonblock) {
        pid = fork();
        if (pid < 0) {
            fatal("Cannot fork: %d", errno);
        } else if (pid > 0) {
            exit(EXIT_SUCCESS);
        }
        sid = setsid();
        if (sid < 0) {
            fatal("New SID creation failure: %d", errno);
        }
    }

    gtk_init(&argc, &argv);
    if (!g_thread_supported())
        g_thread_init(NULL);

    init_directories();
    init_lua(uris);

    /* hide command line parameters so process lists don't leak (possibly
       confidential) URLs */
    for (gint i = 1; i < argc; i++)
        memset(argv[i], 0, strlen(argv[i]));

    /* parse and run configuration file */
    if(!luaH_parserc(globalconf.confpath, TRUE))
        fatal("couldn't find rc file");

    if (!globalconf.windows->len)
        fatal("no windows spawned by rc file, exiting");

    gtk_main();
    return EXIT_SUCCESS;
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
