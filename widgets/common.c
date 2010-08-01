/*
 * widgets/common.c - common widget functions or callbacks
 *
 * Copyright (C) 2010 Mason Larobina <mason.larobina@gmail.com>
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

#include <gtk/gtk.h>

#include "luah.h"
#include "globalconf.h"
#include "common/luaobject.h"
#include "common/lualib.h"
#include "widgets/common.h"

gboolean
key_press_cb(GtkWidget *win, GdkEventKey *ev, widget_t *w)
{
    (void) win;
    gint ret;
    lua_State *L = globalconf.L;
    luaH_object_push(L, w->ref);
    luaH_modifier_table_push(L, ev->state);
    luaH_keystr_push(L, ev->keyval);
    ret = luaH_object_emit_signal(L, -3, "key-press", 2, 1);
    lua_pop(L, 1 + ret);
    return ret ? TRUE : FALSE;
}

gboolean
focus_cb(GtkWidget *win, GdkEventFocus *ev, widget_t *w)
{
    (void) win;
    lua_State *L = globalconf.L;
    luaH_object_push(L, w->ref);
    if (ev->in)
        luaH_object_emit_signal(L, -1, "focus", 0, 0);
    else
        luaH_object_emit_signal(L, -1, "unfocus", 0, 0);
    lua_pop(L, 1);
    return FALSE;
}

/* gtk container add callback */
void
add_cb(GtkContainer *c, GtkWidget *widget, widget_t *w)
{
    (void) c;
    widget_t *child = g_object_get_data(G_OBJECT(widget), "widget");
    lua_State *L = globalconf.L;
    luaH_object_push(L, w->ref);
    luaH_object_push(L, child->ref);
    luaH_object_emit_signal(L, -2, "add", 1, 0);
    lua_pop(L, 1);
}

/* gtk container remove callback */
void
remove_cb(GtkContainer *c, GtkWidget *widget, widget_t *w)
{
    (void) c;
    widget_t *child = g_object_get_data(G_OBJECT(widget), "widget");
    lua_State *L = globalconf.L;
    luaH_object_push(L, w->ref);
    luaH_object_push(L, child->ref);
    luaH_object_emit_signal(L, -2, "remove", 1, 0);
    lua_pop(L, 1);
}

void
parent_set_cb(GtkWidget *widget, GtkObject *old, widget_t *w)
{
    (void) w;
    GtkContainer *new;
    g_object_get(G_OBJECT(widget), "parent", &new, NULL);
    debug("New %p old %p", new, old);
    if (new)
        g_object_unref(G_OBJECT(new));
}

/* set child method for gtk container widgets */
gint
luaH_widget_set_child(lua_State *L)
{
    widget_t *w = luaH_checkudata(L, 1, &widget_class);
    widget_t *child = luaH_checkudataornil(L, 2, &widget_class);

    /* remove old child */
    GtkWidget *widget = gtk_bin_get_child(GTK_BIN(w->widget));
    if (widget) {
        g_object_ref(G_OBJECT(widget));
        gtk_container_remove(GTK_CONTAINER(w->widget), GTK_WIDGET(widget));
    }

    /* add new child to container */
    if (child)
        gtk_container_add(GTK_CONTAINER(w->widget), GTK_WIDGET(child->widget));
    return 0;
}

/* get child method for gtk container widgets */
gint
luaH_widget_get_child(lua_State *L)
{
    widget_t *w = luaH_checkudata(L, 1, &widget_class);
    GtkWidget *widget = gtk_bin_get_child(GTK_BIN(w->widget));
    widget_t *child = NULL;

    if (!widget)
        return 0;

    child = g_object_get_data(G_OBJECT(child), "lua_widget");
    luaH_object_push(L, child->ref);
    return 1;
}

gint
luaH_widget_show(lua_State *L)
{
    widget_t *w = luaH_checkudata(L, 1, &widget_class);
    gtk_widget_show(w->widget);
    return 0;
}

gint
luaH_widget_hide(lua_State *L)
{
    widget_t *w = luaH_checkudata(L, 1, &widget_class);
    gtk_widget_hide(w->widget);
    return 0;
}

gint
luaH_widget_focus(lua_State *L)
{
    widget_t *w = luaH_checkudata(L, 1, &widget_class);
    gtk_widget_grab_focus(w->widget);
    return 0;
}

// vim: ft=c:et:sw=4:ts=8:sts=4:enc=utf-8:tw=80
