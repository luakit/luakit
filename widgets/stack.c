/*
 * widgets/stack.c - gtk stack widget
 *
 * Copyright © 2017 Aidan Holm <aidanholm@gmail.com>
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
luaH_stack_pack(lua_State *L)
{
    widget_t *w = luaH_checkwidget(L, 1);
    widget_t *child = luaH_checkwidget(L, 2);
    gtk_container_add(GTK_CONTAINER (w->widget), GTK_WIDGET(child->widget));
    return 0;
}

static gint
luaH_stack_index(lua_State *L, widget_t *w, luakit_token_t token)
{
    switch(token)
    {
        LUAKIT_WIDGET_INDEX_COMMON(w)
        LUAKIT_WIDGET_CONTAINER_INDEX_COMMON(w)

        PF_CASE(PACK, luaH_stack_pack)
        PB_CASE(HOMOGENEOUS, gtk_stack_get_homogeneous(GTK_STACK(w->widget)))

        case L_TK_VISIBLE_CHILD:
        {
            GtkWidget *widget = gtk_stack_get_visible_child(GTK_STACK(w->widget));
            if (!widget)
                return 0;
            widget_t *child = GOBJECT_TO_LUAKIT_WIDGET(widget);
            luaH_object_push(L, child->ref);
            return 1;
        }

        default:
            break;
    }
    return 0;
}

static gint
luaH_stack_newindex(lua_State *L, widget_t *w, luakit_token_t token)
{
    switch(token) {
        LUAKIT_WIDGET_NEWINDEX_COMMON(w)

        case L_TK_HOMOGENEOUS:
            gtk_stack_set_homogeneous(GTK_STACK(w->widget), luaH_checkboolean(L, 3));
            break;

        case L_TK_VISIBLE_CHILD:
        {
            widget_t *child = luaH_checkwidget(L, 3);
            gtk_stack_set_visible_child(GTK_STACK(w->widget), child->widget);
            break;
        }

        default:
            return 0;
    }

    return luaH_object_property_signal(L, 1, token);
}

widget_t *
widget_stack(lua_State *UNUSED(L), widget_t *w, luakit_token_t UNUSED(token))
{
    w->index = luaH_stack_index;
    w->newindex = luaH_stack_newindex;
    w->widget = gtk_stack_new();

    g_object_connect(G_OBJECT(w->widget),
        LUAKIT_WIDGET_SIGNAL_COMMON(w)
    NULL);

    gtk_widget_show(w->widget);
    return w;
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
