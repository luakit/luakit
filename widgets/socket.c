/*
 * widgets/socket.c - gtk socket widget
 *
 * Copyright © 2010-2011 Fabian Streitel <karottenreibe@gmail.com>
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
#include <stdlib.h>

static void
plug_added_cb(GtkSocket* UNUSED(socket), widget_t *w)
{
    lua_State *L = globalconf.L;
    luaH_object_push(L, w->ref);
    luaH_object_emit_signal(L, -1, "plug-added", 1, 0);
}

static gboolean
plug_removed_cb(GtkSocket* UNUSED(socket), widget_t *w)
{
    lua_State *L = globalconf.L;
    luaH_object_push(L, w->ref);
    luaH_object_emit_signal(L, -1, "plug-removed", 1, 0);
    return FALSE;
}

static gint
luaH_socket_index(lua_State *L, luakit_token_t token)
{
    widget_t *w = luaH_checkwidget(L, 1);

    switch(token)
    {
      LUAKIT_WIDGET_INDEX_COMMON

      /* push integer methods */
      PI_CASE(ID,      (int) gtk_socket_get_id(GTK_SOCKET(w->widget)))
      /* push boolean methods */
      PB_CASE(PLUGGED, gtk_socket_get_plug_window(GTK_SOCKET(w->widget))!=NULL)

      default:
        break;
    }
    return 0;
}

static gint
luaH_socket_newindex(lua_State *L, luakit_token_t token)
{
    widget_t *w = luaH_checkwidget(L, 1);
    if (token == L_TK_ID) {
        gint id = luaL_checkint(L, 2);
        gtk_socket_add_id(GTK_SOCKET(w->widget), (GdkNativeWindow) id);
    }
    return 0;
}

widget_t *
widget_socket(widget_t *w, luakit_token_t UNUSED(token))
{
    w->index = luaH_socket_index;
    w->newindex = luaH_socket_newindex;
    w->destructor = widget_destructor;
    w->widget = gtk_socket_new();
    g_object_set_data(G_OBJECT(w->widget), "lua_widget", (gpointer) w);
    gtk_widget_show(w->widget);
    g_object_connect(G_OBJECT(w->widget),
      "signal::plug-added",   G_CALLBACK(plug_added_cb),   w,
      "signal::plug-removed", G_CALLBACK(plug_removed_cb), w,
      NULL);
    return w;
}
