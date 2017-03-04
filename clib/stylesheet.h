/*
 * Copyright © 2016 Aidan Holm <aidanholm@gmail.com>
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

#ifndef LUAKIT_CLIB_STYLESHEET_H
#define LUAKIT_CLIB_STYLESHEET_H

#include "common/luaobject.h"

#include <lua.h>
#include <glib.h>
#include <webkit2/webkit2.h>

typedef struct {
    LUA_OBJECT_HEADER
    WebKitUserStyleSheet *stylesheet;
    gchar *source;
} lstylesheet_t;

void stylesheet_class_setup(lua_State *);
gpointer luaH_checkstylesheet(lua_State *L, gint idx);

/* Declared in widgets/webview/stylesheets.c */
void webview_stylesheets_regenerate_stylesheet(widget_t *w, lstylesheet_t *stylesheet);

#endif

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
