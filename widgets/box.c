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

#include "luah.h"
#include "widgets/common.h"

/* direct wrapper around gtk_box_pack_start */
static gint
luaH_box_pack_start(lua_State *L)
{
    widget_t *w = luaH_checkwidget(L, 1);
    widget_t *child = luaH_checkwidget(L, 2);
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
    widget_t *w = luaH_checkwidget(L, 1);
    widget_t *child = luaH_checkwidget(L, 2);
    gboolean expand = luaH_checkboolean(L, 3);
    gboolean fill = luaH_checkboolean(L, 4);
    guint padding = luaL_checknumber(L, 5);
    gtk_box_pack_end(GTK_BOX(w->widget), GTK_WIDGET(child->widget),
        expand, fill, padding);
    return 0;
}

/* direct wrapper around gtk_box_reorder_child */
static gint
luaH_box_reorder_child(lua_State *L)
{
    widget_t *w = luaH_checkwidget(L, 1);
    widget_t *child = luaH_checkwidget(L, 2);
    gint pos = luaL_checknumber(L, 3);
    gtk_box_reorder_child(GTK_BOX(w->widget), GTK_WIDGET(child->widget), pos);
    return 0;
}

static gint
luaH_box_index(lua_State *L, luakit_token_t token)
{
    widget_t *w = luaH_checkwidget(L, 1);

    switch(token)
    {
      LUAKIT_WIDGET_INDEX_COMMON
      LUAKIT_WIDGET_CONTAINER_INDEX_COMMON

      /* push class methods */
      PF_CASE(PACK_END,     luaH_box_pack_end)
      PF_CASE(PACK_START,   luaH_box_pack_start)
      PF_CASE(REORDER,      luaH_box_reorder_child)
      /* push boolean properties */
      PB_CASE(HOMOGENEOUS,  gtk_box_get_homogeneous(GTK_BOX(w->widget)))
      /* push string properties */
      PN_CASE(SPACING,      gtk_box_get_spacing(GTK_BOX(w->widget)))

      default:
        break;
    }
    return 0;
}

static gint
luaH_box_newindex(lua_State *L, luakit_token_t token)
{
    widget_t *w = luaH_checkwidget(L, 1);

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

#define BOX_WIDGET_CONSTRUCTOR(type)                                         \
    widget_t *                                                               \
    widget_##type(widget_t *w)                                               \
    {                                                                        \
        w->index = luaH_box_index;                                           \
        w->newindex = luaH_box_newindex;                                     \
        w->destructor = widget_destructor;                                   \
        w->widget = gtk_##type##_new(FALSE, 0);                              \
        g_object_set_data(G_OBJECT(w->widget), "lua_widget", (gpointer) w);  \
        gtk_widget_show(w->widget);                                          \
        g_object_connect(G_OBJECT(w->widget),                                \
          "signal::add",        G_CALLBACK(add_cb),        w,                \
          "signal::parent-set", G_CALLBACK(parent_set_cb), w,                \
          "signal::remove",     G_CALLBACK(remove_cb),     w,                \
          NULL);                                                             \
        return w;                                                            \
    }

BOX_WIDGET_CONSTRUCTOR(vbox)
BOX_WIDGET_CONSTRUCTOR(hbox)

#undef BOX_WIDGET_CONSTRUCTOR

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
