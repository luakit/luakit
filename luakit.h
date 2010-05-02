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

typedef struct {
    GtkWidget *scroll;
    /* WebKit WebView */
    WebKitWebView *view;
    gchar *title;
    guint *progress;
} View;

typedef struct {
    GtkWidget *hbox, *label;
    /* TODO: Order and placement settings */
} Statusbar;

typedef struct {
    /* Root window gtk widgets */
    GtkWidget *win, *vbox, *nbook;
    /* List of WebKit WebView widgets */
    GPtrArray *views;
    /* List of status bars */
    GPtrArray *sbars;
    /* Path to the config file */
    gchar *confpath;
    /* Path of the applications executable (argv[0]) */
    gchar *execpath;
    /* Lua VM state */
    lua_State *L;
    /* exit return code */
    int retval;
} Luakit;

/* Global config/state object */
extern Luakit luakit;

Statusbar* new_sbar(void);
View* new_view(void);
void destroy(void);
void destroy_sbar(Statusbar *s);
void destroy_view(View *v);

#endif
// vim: ft=c:et:sw=4:ts=8:sts=4:enc=utf-8:tw=80
