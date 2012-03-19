/*
 * widgets/box.c - gtk hbox & vbox container widgets
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
luaH_box_pack(lua_State *L)
{
    widget_t *w = luaH_checkwidget(L, 1);
    widget_t *child = luaH_checkwidget(L, 2);

    gint top = lua_gettop(L);
    gboolean expand = FALSE, fill = FALSE, start = TRUE;
    guint padding = 0;

    /* check for options table */
    if (top > 2 && !lua_isnil(L, 3)) {
        luaH_checktable(L, 3);

        /* pack child from start or end of container? */
        if (luaH_rawfield(L, 3, "from"))
            start = L_TK_END == l_tokenize(lua_tostring(L, -1)) ? FALSE : TRUE;

        /* expand? */
        if (luaH_rawfield(L, 3, "expand"))
            expand = lua_toboolean(L, -1) ? TRUE : FALSE;

        /* fill? */
        if (luaH_rawfield(L, 3, "fill"))
            fill = lua_toboolean(L, -1) ? TRUE : FALSE;

        /* padding? */
        if (luaH_rawfield(L, 3, "padding"))
            padding = (guint)lua_tonumber(L, -1);

        /* return stack to original state */
        lua_settop(L, top);
    }

    if (start)
        gtk_box_pack_start(GTK_BOX(w->widget), GTK_WIDGET(child->widget),
                expand, fill, padding);
    else
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
luaH_box_index(lua_State *L, widget_t *w, luakit_token_t token)
{
    switch(token) {
      LUAKIT_WIDGET_INDEX_COMMON(w)
      LUAKIT_WIDGET_CONTAINER_INDEX_COMMON(w)

      /* push class methods */
      PF_CASE(PACK,         luaH_box_pack)
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
luaH_box_newindex(lua_State *L, widget_t *w, luakit_token_t token)
{
    switch(token) {
      LUAKIT_WIDGET_NEWINDEX_COMMON(w)

      case L_TK_HOMOGENEOUS:
        gtk_box_set_homogeneous(GTK_BOX(w->widget), luaH_checkboolean(L, 3));
        break;

      case L_TK_SPACING:
        gtk_box_set_spacing(GTK_BOX(w->widget), luaL_checknumber(L, 3));
        break;

      default:
        return 0;
    }

    return luaH_object_property_signal(L, 1, token);
}

widget_t *
widget_box(widget_t *w, luakit_token_t token)
{
    w->index = luaH_box_index;
    w->newindex = luaH_box_newindex;
    w->destructor = widget_destructor;

    w->widget = (token == L_TK_VBOX) ? gtk_vbox_new(FALSE, 0) :
            gtk_hbox_new(FALSE, 0);

    g_object_connect(G_OBJECT(w->widget),
      "signal::add",        G_CALLBACK(add_cb),        w,
      "signal::parent-set", G_CALLBACK(parent_set_cb), w,
      "signal::remove",     G_CALLBACK(remove_cb),     w,
      NULL);
    gtk_widget_show(w->widget);
    return w;
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
