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

static gint
luaH_paned_pack(lua_State *L)
{
    widget_t *w = luaH_checkwidget(L, 1);
    widget_t *child = luaH_checkwidget(L, 2);
    gint top = lua_gettop(L);
    gboolean resize = TRUE, shrink = TRUE;
    if (top > 2 && !lua_isnil(L, 3)) {
        luaH_checktable(L, 3);
        if (luaH_rawfield(L, 3, "resize"))
            resize = lua_toboolean(L, -1) ? TRUE : FALSE;
        if (luaH_rawfield(L, 3, "shrink"))
            shrink = lua_toboolean(L, -1) ? TRUE : FALSE;
        lua_settop(L, top);
    }

    /* get packing position from C closure upvalue */
    luakit_token_t t = (luakit_token_t)lua_tonumber(L, lua_upvalueindex(1));

    if (t == L_TK_PACK1)
        gtk_paned_pack1(GTK_PANED(w->widget), GTK_WIDGET(child->widget),
                resize, shrink);
    else
        gtk_paned_pack2(GTK_PANED(w->widget), GTK_WIDGET(child->widget),
                resize, shrink);
    return 0;
}

static gint
luaH_paned_get_child(lua_State *L, widget_t *w, gint n)
{
    GtkWidget *widget = NULL;
    if (n == 1)
        widget = gtk_paned_get_child1(GTK_PANED(w->widget));
    else
        widget = gtk_paned_get_child2(GTK_PANED(w->widget));

    if (!widget)
        return 0;

    widget_t *child = GOBJECT_TO_LUAKIT_WIDGET(widget);
    luaH_object_push(L, child->ref);
    return 1;
}

static gint
luaH_paned_index(lua_State *L, widget_t *w, luakit_token_t token)
{
    switch(token) {
      LUAKIT_WIDGET_INDEX_COMMON(w)
      LUAKIT_WIDGET_CONTAINER_INDEX_COMMON(w)

      /* push paned widget methods */
      case L_TK_PACK1:
      case L_TK_PACK2:
        lua_pushnumber(L, (gint) token);
        lua_pushcclosure(L, luaH_paned_pack, 1);
        return 1;

      case L_TK_TOP:
      case L_TK_LEFT:
        return luaH_paned_get_child(L, w, 1);

      case L_TK_BOTTOM:
      case L_TK_RIGHT:
        return luaH_paned_get_child(L, w, 2);

      default:
        break;
    }
    return 0;
}

static gint
luaH_paned_newindex(lua_State *L, widget_t *w, luakit_token_t token)
{
    switch(token) {
      LUAKIT_WIDGET_NEWINDEX_COMMON(w)

      default:
        break;
    }
    return 0;
}

widget_t *
widget_paned(widget_t *w, luakit_token_t token)
{
    w->index = luaH_paned_index;
    w->newindex = luaH_paned_newindex;
    w->destructor = widget_destructor;

#if GTK_CHECK_VERSION(3,0,0)
    w->widget = gtk_paned_new((token == L_TK_VPANED) ? GTK_ORIENTATION_VERTICAL: GTK_ORIENTATION_HORIZONTAL);
#else
    w->widget = (token == L_TK_VPANED) ? gtk_vpaned_new() :
            gtk_hpaned_new();
#endif

    g_object_connect(G_OBJECT(w->widget),
      "signal::add",        G_CALLBACK(add_cb),        w,
      "signal::parent-set", G_CALLBACK(parent_set_cb), w,
      "signal::remove",     G_CALLBACK(remove_cb),     w,
      NULL);
    gtk_widget_show(w->widget);
    return w;
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
