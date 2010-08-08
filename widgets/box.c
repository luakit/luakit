/*
 * widgets/box.c - gtk hbox & vbox container widgets
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

/* TODO
 *  - Add `remove(child)` method to remove child widgets from the box
 *  - Add `reorder(child, index)` method to re-order child widgets
 *  - Add `get_children()` method to return a table of widgets in the box
 *  - In the box destructor function detach all child windows
 */


#include "luah.h"
#include "widgets/common.h"

/* direct wrapper around gtk_box_pack_start */
static gint
luaH_box_pack_start(lua_State *L)
{
    widget_t *w = luaH_checkudata(L, 1, &widget_class);
    widget_t *child = luaH_checkudata(L, 2, &widget_class);
    gboolean expand = luaH_checkboolean(L, 3);
    gboolean fill = luaH_checkboolean(L, 4);
    guint padding = luaL_checknumber(L, 5);
    gtk_box_pack_start(GTK_BOX(w->widget), GTK_WIDGET(child->widget),
        expand, fill, padding);
    return 0;
}

/* direct wrapper around gtk_box_pack_end */
static gint
luaH_box_pack_end(lua_State *L)
{
    widget_t *w = luaH_checkudata(L, 1, &widget_class);
    widget_t *child = luaH_checkudata(L, 2, &widget_class);
    gboolean expand = luaH_checkboolean(L, 3);
    gboolean fill = luaH_checkboolean(L, 4);
    guint padding = luaL_checknumber(L, 5);
    gtk_box_pack_end(GTK_BOX(w->widget), GTK_WIDGET(child->widget),
        expand, fill, padding);
    return 0;
}

static gint
luaH_box_index(lua_State *L, luakit_token_t token)
{
    widget_t *w = luaH_checkudata(L, 1, &widget_class);

    switch(token)
    {
      case L_TK_DESTROY:
        lua_pushcfunction(L, luaH_widget_destroy);
        return 1;

      case L_TK_PACK_START:
        lua_pushcfunction(L, luaH_box_pack_start);
        return 1;

      case L_TK_PACK_END:
        lua_pushcfunction(L, luaH_box_pack_end);
        return 1;

      case L_TK_HOMOGENEOUS:
        lua_pushboolean(L, gtk_box_get_homogeneous(GTK_BOX(w->widget)));
        return 1;

      case L_TK_SPACING:
        lua_pushnumber(L, gtk_box_get_spacing(GTK_BOX(w->widget)));
        return 1;

      case L_TK_SHOW:
        lua_pushcfunction(L, luaH_widget_show);
        return 1;

      case L_TK_HIDE:
        lua_pushcfunction(L, luaH_widget_hide);
        return 1;

      default:
        break;
    }
    return 0;
}

static gint
luaH_box_newindex(lua_State *L, luakit_token_t token)
{
    widget_t *w = luaH_checkudata(L, 1, &widget_class);

    switch(token)
    {
      case L_TK_HOMOGENEOUS:
        gtk_box_set_homogeneous(GTK_BOX(w->widget), luaH_checkboolean(L, 3));
        break;

      case L_TK_SPACING:
        gtk_box_set_spacing(GTK_BOX(w->widget), luaL_checknumber(L, 3));
        break;

      default:
        return 0;
    }

    return luaH_object_emit_property_signal(L, 1);
}

void
box_destructor(widget_t *w)
{
    gtk_widget_destroy(w->widget);
}

#define BOX_WIDGET_CONSTRUCTOR(type)                                         \
    widget_t *                                                               \
    widget_##type(widget_t *w)                                               \
    {                                                                        \
        w->index = luaH_box_index;                                           \
        w->newindex = luaH_box_newindex;                                     \
        w->destructor = box_destructor;                                      \
        w->widget = gtk_##type##_new(FALSE, 0);                              \
        g_object_set_data(G_OBJECT(w->widget), "widget", (gpointer) w);      \
        gtk_widget_show(w->widget);                                          \
        g_object_connect((GObject*)w->widget,                                \
          "signal::add",        add_cb,        w,                            \
          "signal::parent-set", parent_set_cb, w,                            \
          "signal::remove",     remove_cb,     w,                            \
          NULL);                                                             \
        return w;                                                            \
    }

BOX_WIDGET_CONSTRUCTOR(vbox)
BOX_WIDGET_CONSTRUCTOR(hbox)

#undef BOX_WIDGET_CONSTRUCTOR

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
