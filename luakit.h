/*
 * luakit.h - luakit main functions
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

#ifndef LUAKIT_LUAKIT_H
#define LUAKIT_LUAKIT_H

#define _GNU_SOURCE

#include <JavaScriptCore/JavaScript.h>
#include <basedir.h>
#include <basedir_fs.h>
#include <glib/gstdio.h>
#include <gtk/gtk.h>
#include <lauxlib.h>
#include <lua.h>
#include <lualib.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>
#include <webkit/webkit.h>

#include "common/signal.h"

typedef struct {
    GtkWidget *hbox, *label;
    /* TODO: Order and placement settings */
} Statusbar;

typedef struct {
    /* Root window gtk widgets */
    GtkWidget *win, *vbox, *nbook;
    /* List of status bars */
    GPtrArray *sbars;
    /* Path to the config file */
    gchar *confpath;
    /* Path of the applications executable (argv[0]) */
    gchar *execpath;
    /* Lua VM state */
    lua_State *L;
    /* global signals */
    signal_t *signals;
    /* exit return code */
    int retval;
    /* tab reverse lookup by scroll widget */
    GHashTable *tabs;
} Luakit;

/* Global config/state object */
extern Luakit luakit;

Statusbar* new_sbar(void);
void destroy(void);
void destroy_sbar(Statusbar *s);

#endif
// vim: ft=c:et:sw=4:ts=8:sts=4:enc=utf-8:tw=80
