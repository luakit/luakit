/*
 * window.h - window manager
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

#ifndef LUAKIT_WINDOW_H
#define LUAKIT_WINDOW_H

#include <gtk/gtk.h>

typedef struct window_t window_t;

#include "widget.h"

struct window_t
{
    LUA_OBJECT_HEADER
    /* gtk window widget */
    GtkWidget *win;
    /* store lua object ref to the gtk window */
    gpointer ref;
    /* window title */
    gchar *title;
    /* child widget */
    widget_t *child;
    /* path to window icon */
    gchar *icon;
};

lua_class_t window_class;
void window_class_setup(lua_State *);

GPtrArray *windows;

#endif
// vim: ft=c:et:sw=4:ts=8:sts=4:enc=utf-8:tw=80
