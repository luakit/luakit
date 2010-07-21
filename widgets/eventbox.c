/*
 * widgets/eventbox.c - gtk eventbox widget
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

#include "luah.h"
#include "widgets/common.h"

static gint
luaH_eventbox_index(lua_State *L, luakit_token_t token)
{
    luaH_checkudata(L, 1, &widget_class);
    switch(token)
    {
      case L_TK_SET_CHILD:
        lua_pushcfunction(L, luaH_widget_set_child);
        return 1;

      case L_TK_GET_CHILD:
        lua_pushcfunction(L, luaH_widget_get_child);
        return 1;

      default:
        break;
    }
    return 0;
}

static gint
luaH_eventbox_newindex(lua_State *L, luakit_token_t token)
{
    (void) L;
    (void) token;
    return 0;
}

static void
eventbox_destructor(widget_t *w)
{
    gtk_widget_destroy(w->widget);
}

widget_t *
widget_eventbox(widget_t *w)
{
    w->index = luaH_eventbox_index;
    w->newindex = luaH_eventbox_newindex;
    w->destructor = eventbox_destructor;

    w->widget = gtk_event_box_new();
    g_object_set_data(G_OBJECT(w->widget), "widget", (gpointer) w);
    gtk_widget_show(w->widget);

    g_object_connect((GObject*)w->widget,
      "signal::add",        (GCallback)add_cb,        w,
      "signal::parent-set", (GCallback)parent_set_cb, w,
      "signal::remove",     (GCallback)remove_cb,     w,
      NULL);

    return w;
}

// vim: ft=c:et:sw=4:ts=8:sts=4:enc=utf-8:tw=80
