/*
 * clib/inspector.h - WebKitWebInspector wrapper header
 *
 * Copyright © 2009 Julien Danjou <julien@danjou.info>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 *
 */

#ifndef LUAKIT_CLIB_INSPECTOR_H
#define LUAKIT_CLIB_INSPECTOR_H

#include <lua.h>
#include <webkit/webkit.h>
#include "clib/widget.h"

typedef struct
{
    LUA_OBJECT_HEADER
    WebKitWebInspector* inspector;
    widget_t* webview;
    widget_t* widget;
    gpointer ref;
    gboolean visible;
    gboolean attached;
} inspector_t;

void inspector_class_setup(lua_State *);
inspector_t* luaH_inspector_new(lua_State *, widget_t *);
void inspector_destroy(lua_State *, inspector_t *);

#endif

// vim: filetype=c:expandtab:shiftwidth=4:tabstop=8:softtabstop=4:textwidth=80
