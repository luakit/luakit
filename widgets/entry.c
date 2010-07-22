/*
 * widgets/entry.c - gtk entry widget wrapper
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
luaH_entry_index(lua_State *L, luakit_token_t token)
{
    widget_t *w = luaH_checkudata(L, 1, &widget_class);

    switch(token)
    {
      case L_TK_TEXT:
        lua_pushstring(L, gtk_entry_get_text(GTK_ENTRY(w->widget)));
        return 1;

      default:
        break;
    }
    return 0;
}

static gint
luaH_entry_newindex(lua_State *L, luakit_token_t token)
{
    size_t len;
    widget_t *w = luaH_checkudata(L, 1, &widget_class);

    switch(token)
    {
      case L_TK_TEXT:
        gtk_entry_set_text(GTK_ENTRY(w->widget),
            luaL_checklstring(L, 3, &len));
        break;

      default:
        return 0;
    }

    return luaH_object_emit_property_signal(L, 1);
}

static void
entry_destructor(widget_t *w)
{
    gtk_widget_destroy(w->widget);
}

widget_t *
widget_entry(widget_t *w)
{
    w->index = luaH_entry_index;
    w->newindex = luaH_entry_newindex;
    w->destructor = entry_destructor;

    /* create gtk label widget as main widget */
    w->widget = gtk_entry_new();
    g_object_set_data(G_OBJECT(w->widget), "widget", (gpointer) w);

    /* setup default settings */
    gtk_entry_set_inner_border(GTK_ENTRY(w->widget), NULL);

    g_object_connect((GObject*)w->widget,
      "signal::focus-in-event",    (GCallback)focus_cb,       w,
      "signal::focus-out-event",   (GCallback)focus_cb,       w,
      "signal::key-press-event",   (GCallback)key_press_cb,   w,
      "signal::key-release-event", (GCallback)key_release_cb, w,
      "signal::parent-set",        (GCallback)parent_set_cb,  w,
      NULL);

    gtk_widget_show(w->widget);
    return w;
}

// vim: ft=c:et:sw=4:ts=8:sts=4:enc=utf-8:tw=80
