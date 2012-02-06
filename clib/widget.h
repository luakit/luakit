/*
 * clib/widget.h - widget managing header
 *
 * Copyright © 2010 Mason Larobina <mason.larobina@gmail.com>
 * Copyright © 2007-2009 Julien Danjou <julien@danjou.info>
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

#ifndef LUAKIT_CLIB_WIDGET_H
#define LUAKIT_CLIB_WIDGET_H

typedef struct widget_t widget_t;

#include "common/util.h"
#include "common/luaclass.h"
#include "common/luaobject.h"
#include "luah.h"

#include <gtk/gtk.h>

typedef widget_t *(widget_constructor_t)(widget_t *, luakit_token_t);
typedef void (widget_destructor_t)(widget_t *);

widget_constructor_t widget_box;
widget_constructor_t widget_entry;
widget_constructor_t widget_eventbox;
widget_constructor_t widget_label;
widget_constructor_t widget_notebook;
widget_constructor_t widget_paned;
widget_constructor_t widget_webview;
widget_constructor_t widget_window;
widget_constructor_t widget_socket;

typedef const struct {
    luakit_token_t tok;
    const gchar *name;
    widget_constructor_t *wc;
} widget_info_t;

/* Widget */
struct widget_t
{
    LUA_OBJECT_HEADER
    /* Widget type information */
    widget_info_t *info;
    /* Widget destructor */
    widget_destructor_t *destructor;
    /* Index function */
    gint (*index)(lua_State *, luakit_token_t);
    /* Newindex function */
    gint (*newindex)(lua_State *, luakit_token_t);
    /* Lua object ref */
    gpointer ref;
    /* Main gtk widget */
    GtkWidget *widget;
    /* Misc private data */
    gpointer data;
};

lua_class_t widget_class;
void widget_class_setup(lua_State *);

static inline widget_t*
luaH_checkwidget(lua_State *L, gint udx)
{
    widget_t *w = luaH_checkudata(L, udx, &widget_class);
    if (!w->widget)
        luaL_argerror(L, udx, "using destroyed widget");
    return w;
}

static inline widget_t*
luaH_checkwidgetornil(lua_State *L, gint udx)
{
    if (lua_isnil(L, udx))
        return NULL;
    return luaH_checkwidget(L, udx);
}

#define luaH_towidget(L, udx) luaH_toudata(L, udx, &widget_class)

#endif

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
