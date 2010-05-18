/*
 * box.c - gtk container widgets
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
#include "widget.h"

typedef struct
{
    /* Gtk box */
    GtkWidget *box;
    /* Reverse child widget lookup */
    GHashTable *children;

} box_data_t;

void
box_pack(lua_State *L, widget_t *w, widget_t *child, gboolean start,
        gboolean expand, gboolean fill, guint padding)
{
    box_data_t *d = w->data;

    if (!child->widget)
        luaL_error(L, "unable to insert non-gtk widget");

    if (child->parent || child->window)
        luaL_error(L, "widget already has parent");

    if (start)
        gtk_box_pack_start(GTK_BOX(d->box), child->widget,
                expand, fill, padding);
    else
        gtk_box_pack_end(GTK_BOX(d->box), child->widget,
                expand, fill, padding);

    /* add reverse widget lookup by gtk widget */
    g_hash_table_insert(d->children, child->widget, child);

    child->parent = w;
}

static gint
luaH_box_pack_start(lua_State *L)
{
    widget_t *w = luaH_checkudata(L, 1, &widget_class);
    widget_t *child = luaH_checkudata(L, 2, &widget_class);
    gboolean expand = luaH_checkboolean(L, 3);
    gboolean fill = luaH_checkboolean(L, 4);
    guint padding = luaL_checknumber(L, 5);
    box_pack(L, w, child, TRUE, expand, fill, padding);
    return 0;
}

static gint
luaH_box_pack_end(lua_State *L)
{
    widget_t *w = luaH_checkudata(L, 1, &widget_class);
    widget_t *child = luaH_checkudata(L, 2, &widget_class);
    gboolean expand = luaH_checkboolean(L, 3);
    gboolean fill = luaH_checkboolean(L, 4);
    guint padding = luaL_checknumber(L, 5);
    box_pack(L, w, child, TRUE, expand, fill, padding);
    return 0;
}

static gint
luaH_box_index(lua_State *L, luakit_token_t token)
{
    widget_t *w = luaH_checkudata(L, 1, &widget_class);
    box_data_t *d = w->data;

    switch(token)
    {
      case L_TK_PACK_START:
        lua_pushcfunction(L, luaH_box_pack_start);
        return 1;

      case L_TK_PACK_END:
        lua_pushcfunction(L, luaH_box_pack_end);
        return 1;

      case L_TK_HOMOGENEOUS:
        lua_pushboolean(L, gtk_box_get_homogeneous(GTK_BOX(d->box)));
        return 1;

      case L_TK_SPACING:
        lua_pushnumber(L, gtk_box_get_spacing(GTK_BOX(d->box)));
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
    box_data_t *d = w->data;

    switch(token)
    {
      case L_TK_HOMOGENEOUS:
        gtk_box_set_homogeneous(GTK_BOX(d->box), luaH_checkboolean(L, -1));
        break;

      case L_TK_SPACING:
        gtk_box_set_spacing(GTK_BOX(d->box), luaL_checknumber(L, -1));
        break;

      default:
        break;
    }
    return 0;
}

void
box_destructor(widget_t *w)
{
    box_data_t *d = w->data;

    /* destroy gtk widgets */
    gtk_widget_destroy(d->box);

    w->widget = d->box = NULL;

    /* destroy lookup table */
    g_hash_table_destroy(d->children);
}

#define BOX_WIDGET_CONSTRUCTOR(type)                                         \
    widget_t *                                                               \
    widget_##type(widget_t *w)                                               \
    {                                                                        \
        w->index = luaH_box_index;                                           \
        w->newindex = luaH_box_newindex;                                     \
        w->destructor = box_destructor;                                      \
        box_data_t *d = w->data = g_new0(box_data_t, 1);                     \
        w->widget = d->box = gtk_##type##_new(FALSE, 0);                     \
        gtk_widget_show(d->box);                                             \
        /* Create reverse lookup table for child widgets */                  \
        d->children = g_hash_table_new(g_direct_hash, g_direct_equal);       \
        return w;                                                            \
    }

BOX_WIDGET_CONSTRUCTOR(vbox)
BOX_WIDGET_CONSTRUCTOR(hbox)

#undef BOX_WIDGET_CONSTRUCTOR

// vim: ft=c:et:sw=4:ts=8:sts=4:enc=utf-8:tw=80
