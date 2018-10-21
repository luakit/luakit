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

#include "common/util.h"
#include "globalconf.h"
#include "luah.h"
#include "ipc.h"
#include "log.h"
#include "web_context.h"

#include <errno.h>
#include <gtk/gtk.h>
#include <locale.h>
#include <signal.h>
#include <stdlib.h>
#include <sys/wait.h>
#include <unistd.h>
#include <webkit2/webkit2.h>

#if !WEBKIT_CHECK_VERSION(2,16,0)
#error Your version of WebKit is outdated!
#endif

static void
init_directories(void)
{
    /* create luakit directory */
    globalconf.cache_dir  = g_build_filename(g_get_user_cache_dir(),  "luakit", globalconf.profile, NULL);
    globalconf.config_dir = g_build_filename(g_get_user_config_dir(), "luakit", globalconf.profile, NULL);
    globalconf.data_dir   = g_build_filename(g_get_user_data_dir(),   "luakit", globalconf.profile, NULL);
    g_mkdir_with_parents(globalconf.cache_dir,  0700);
    g_mkdir_with_parents(globalconf.config_dir, 0700);
    g_mkdir_with_parents(globalconf.data_dir,   0700);
}

static void
parse_log_level_option(gchar *log_lvl)
{
    gchar **parts = g_strsplit(log_lvl, ",", 0);

    for (gchar **part = parts; *part; part++) {
        log_level_t lvl;
        if (!log_level_from_string(&lvl, *part))
            log_set_verbosity("all", lvl);
        else {
            gchar *sep = strchr(*part, '=');
            if (sep && !log_level_from_string(&lvl, sep+1)) {
                *sep = '\0';
                log_set_verbosity(*part, lvl);
            } else
                warn("ignoring unrecognized --log option '%s'", *part);
        }
    }
    g_strfreev(parts);
}

/* load command line options into luakit and return uris to load */
static gchar **
parseopts(int *argc, gchar *argv[], gboolean **nonblock)
{
    GOptionContext *context;
    gboolean *version_only = NULL;
    gboolean *check_only = NULL;
    gchar **uris = NULL;
    globalconf.profile = NULL;
    gboolean verbose = FALSE;
    gchar *log_lvl = NULL;

    /* save luakit exec path */
    globalconf.execpath = g_strdup(argv[0]);
    globalconf.nounique = FALSE;

    /* define command line options */
    const GOptionEntry entries[] = {
        { "check",    'k', 0, G_OPTION_ARG_NONE,         &check_only,          "check config and exit",     NULL   },
        { "config",   'c', 0, G_OPTION_ARG_STRING,       &globalconf.confpath, "configuration file to use", "FILE" },
        { "profile",  'p', 0, G_OPTION_ARG_STRING,       &globalconf.profile,  "profile name to use",       "NAME" },
        { "nonblock", 'n', 0, G_OPTION_ARG_NONE,         nonblock,             "run in background",         NULL   },
        { "nounique", 'U', 0, G_OPTION_ARG_NONE,         &globalconf.nounique, "ignore libunique bindings", NULL   },
        { "uri",      'u', 0, G_OPTION_ARG_STRING_ARRAY, &uris,                "uri(s) to load at startup", "URI"  },
        { "verbose",  'v', 0, G_OPTION_ARG_NONE,         &verbose,             "print verbose output",      NULL   },
        { "log",      'l', 0, G_OPTION_ARG_STRING,       &log_lvl,             "specify precise log level", "NAME" },
        { "version",  'V', 0, G_OPTION_ARG_NONE,         &version_only,        "print version and exit",    NULL   },
        { NULL,       0,   0, 0,                         NULL,                 NULL,                        NULL   },
    };

    /* Save a copy of argv */
    globalconf.argv = g_ptr_array_new_with_free_func(g_free);
    for (gint i = 0; i < *argc; ++i)
        g_ptr_array_add(globalconf.argv, g_strdup(argv[i]));

    /* parse command line options */
    context = g_option_context_new("[URI...]");
    g_option_context_add_main_entries(context, entries, NULL);
    g_option_context_add_group(context, gtk_get_option_group(FALSE));
    g_option_context_parse(context, argc, &argv, NULL);
    g_option_context_free(context);

    /* Trim unparsed arguments off copy of argv */
    for (gint i = 0; i < *argc; ++i) {
        while ((unsigned)i < globalconf.argv->len && !strcmp(g_ptr_array_index(globalconf.argv, i), argv[i]))
            g_ptr_array_remove_index(globalconf.argv, i);
    }

    /* print version and exit */
    if (version_only) {
        g_printf("luakit %s\n", VERSION);
        g_printf("  built with webkit %i.%i.%i ", WEBKIT_MAJOR_VERSION, WEBKIT_MINOR_VERSION, WEBKIT_MICRO_VERSION);
        g_printf("(installed version: %u.%u.%u)\n", webkit_get_major_version(), webkit_get_minor_version(), webkit_get_micro_version());
        exit(EXIT_SUCCESS);
    }

    if (!log_lvl)
        log_set_verbosity("all", verbose ? LOG_LEVEL_verbose : LOG_LEVEL_info);
    else {
        log_set_verbosity("all", LOG_LEVEL_info);
        parse_log_level_option(log_lvl);
        if (verbose)
            warn("invalid mix of -v and -l, ignoring -v...");
    }

    /* check config syntax and exit */
    if (check_only) {
        init_directories();
        luaH_init(NULL);
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
        return g_strdupv(argv + 1);
}

#if __GLIBC__ == 2 && __GLIBC_MINOR__ >= 50
static GLogWriterOutput
glib_log_writer(GLogLevelFlags log_level_flags, const GLogField *fields, gsize n_fields, gpointer UNUSED(user_data))
{
    const gchar *log_domain = "(unknown)",
                *message = "(empty)",
                *code_file = "(unknown)",
                *code_line = "(unknown)";

    for (gsize i = 0; i < n_fields; ++i) {
        if (!strcmp(fields[i].key, "GLIB_DOMAIN")) log_domain = fields[i].value;
        if (!strcmp(fields[i].key, "MESSAGE")) message = fields[i].value;
        if (!strcmp(fields[i].key, "CODE_FILE")) code_file = fields[i].value;
        if (!strcmp(fields[i].key, "CODE_LINE")) code_line = fields[i].value;
    }

    /* Probably not necessary, but just in case... */
    if (!(G_LOG_LEVEL_MASK & log_level_flags))
        return G_LOG_WRITER_UNHANDLED;

    log_level_t log_level = ((log_level_t[]){
        [G_LOG_LEVEL_ERROR]    = LOG_LEVEL_fatal,
        [G_LOG_LEVEL_CRITICAL] = LOG_LEVEL_warn,
        [G_LOG_LEVEL_WARNING]  = LOG_LEVEL_warn,
        [G_LOG_LEVEL_MESSAGE]  = LOG_LEVEL_info,
        [G_LOG_LEVEL_INFO]     = LOG_LEVEL_verbose,
        [G_LOG_LEVEL_DEBUG]    = LOG_LEVEL_debug,
    })[log_level_flags];

    _log(log_level, code_line, code_file, "%s: %s", log_domain, message);
    return G_LOG_WRITER_HANDLED;
}
#endif

gint
main(gint argc, gchar *argv[])
{
    gboolean *nonblock = NULL;
    globalconf.starttime = l_time();

    log_init();

    /* set numeric locale to C (required for compatibility with
       LuaJIT and luakit scripts) */
    gtk_disable_setlocale();
    setlocale(LC_ALL, "");
    setlocale(LC_NUMERIC, "C");

    /* parse command line opts and get uris to load */
    gchar **uris = parseopts(&argc, argv, &nonblock);

    /* hide command line parameters so process lists don't leak (possibly
       confidential) URLs */
    for (gint i = 1; i < argc; i++)
        memset(argv[i], 0, strlen(argv[i]));

    globalconf.windows = g_ptr_array_new();

    /* if non block mode - respawn, detach and continue in child */
    if (nonblock) {
        pid_t pid = fork();
        if (pid < 0) {
            fatal("Cannot fork: %d", errno);
        } else if (pid > 0) {
            exit(EXIT_SUCCESS);
        }
        pid_t sid = setsid();
        if (sid < 0) {
            fatal("New SID creation failure: %d", errno);
        }
    }

    gtk_init(&argc, &argv);

#if __GLIBC__ == 2 && __GLIBC_MINOR__ >= 50
    g_log_set_writer_func(glib_log_writer, NULL, NULL);
#endif
    init_directories();
    web_context_init();
    ipc_init();
    luaH_init(uris);

    /* parse and run configuration file */
    if (!luaH_parserc(globalconf.confpath, TRUE))
        fatal("couldn't find rc file");

    if (!globalconf.windows->len)
        fatal("no windows spawned by rc file, exiting");

    gtk_main();
    return EXIT_SUCCESS;
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
