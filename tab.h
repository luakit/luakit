/*
 * tab.h - webkit webview widget
 *
 * Copyright (C) 2010 Mason Larobina <mason.larobina@gmail.com>
 * Copyright (C) 2007-2009 Julien Danjou <julien@danjou.info>
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

#ifndef LUAKIT_TAB_H
#define LUAKIT_TAB_H

#include "common/luaobject.h"

/* View */
typedef struct  {
    LUA_OBJECT_HEADER
    /* index function */
    gint (*index)(lua_State *, const gchar *);
    /* newindex function */
    gint (*newindex)(lua_State *, const gchar *);
    /* webkit webview */
    WebKitWebView *view;
    /* scrollable area which holds the webview */
    GtkWidget *scroll;
    /* current uri */
    gchar *uri;
    /* notebook tab title */
    gchar *title;
    /* webview load progress */
    gint progress;
    /* lua class instance object ref */
    gpointer ref;
    /* is anchored inside the root gtk notebook */
    gboolean anchored;
} tab_t;

lua_class_t tab_class;
void tab_class_setup(lua_State *);

#endif

// vim: ft=c:et:sw=4:ts=8:sts=4:enc=utf-8:tw=80
