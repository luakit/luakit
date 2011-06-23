/*
 * widgets/paned.c - gtk paned container widget
 *
 * Copyright © 2010 Mason Larobina <mason.larobina@gmail.com>
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

/* direct wrapper around gtk_paned_pack */
static gint
luaH_paned_pack(lua_State *L)
{
    widget_t *w = luaH_checkwidget(L, 1);
    guint n = luaL_checknumber(L, 2);
    widget_t *child = luaH_checkwidget(L, 3);
    gboolean resize = luaH_checkboolean(L, 4);
    gboolean shrink = luaH_checkboolean(L, 5);
    if (n == 1) {
        gtk_paned_pack1(GTK_PANED(w->widget), GTK_WIDGET(child->widget),
            resize, shrink);
    } else {
        gtk_paned_pack2(GTK_PANED(w->widget), GTK_WIDGET(child->widget),
            resize, shrink);
    }
    return 0;
}

static gint
luaH_paned_index(lua_State *L, luakit_token_t token)
{
    switch(token)
    {
      LUAKIT_WIDGET_INDEX_COMMON
      LUAKIT_WIDGET_CONTAINER_INDEX_COMMON

      /* push class methods */
      PF_CASE(PACK,         luaH_paned_pack)

      default:
        break;
    }
    return 0;
}

#define PANED_WIDGET_CONSTRUCTOR(type)                                       \
    widget_t *                                                               \
    widget_##type(widget_t *w)                                               \
    {                                                                        \
        w->index = luaH_paned_index;                                         \
        w->newindex = NULL;                                                  \
        w->destructor = widget_destructor;                                   \
        w->widget = gtk_##type##_new();                                      \
        g_object_set_data(G_OBJECT(w->widget), "lua_widget", (gpointer) w);  \
        gtk_widget_show(w->widget);                                          \
        g_object_connect(G_OBJECT(w->widget),                                \
          "signal::add",        G_CALLBACK(add_cb),        w,                \
          "signal::parent-set", G_CALLBACK(parent_set_cb), w,                \
          "signal::remove",     G_CALLBACK(remove_cb),     w,                \
          NULL);                                                             \
        return w;                                                            \
    }

PANED_WIDGET_CONSTRUCTOR(vpaned)
PANED_WIDGET_CONSTRUCTOR(hpaned)

#undef PANED_WIDGET_CONSTRUCTOR

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
