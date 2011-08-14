/*
 * widgets/common.c - common widget functions or callbacks
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

#include <gtk/gtk.h>

#include "luah.h"
#include "globalconf.h"
#include "common/luaobject.h"
#include "common/lualib.h"
#include "widgets/common.h"

gboolean
key_press_cb(GtkWidget* UNUSED(win), GdkEventKey *ev, widget_t *w)
{
    lua_State *L = globalconf.L;
    luaH_object_push(L, w->ref);
    luaH_modifier_table_push(L, ev->state);
    luaH_keystr_push(L, ev->keyval);
    gint ret = luaH_object_emit_signal(L, -3, "key-press", 2, 1);
    gboolean catch = ret && lua_toboolean(L, -1) ? TRUE : FALSE;
    lua_pop(L, ret + 1);
    return catch;
}

gboolean
button_cb(GtkWidget* UNUSED(win), GdkEventButton *ev, widget_t *w)
{
    gint ret;
    lua_State *L = globalconf.L;
    luaH_object_push(L, w->ref);
    luaH_modifier_table_push(L, ev->state);
    lua_pushinteger(L, ev->button);

    switch (ev->type) {
      case GDK_2BUTTON_PRESS:
        ret = luaH_object_emit_signal(L, -3, "button-double-click", 2, 1);
        break;
      case GDK_BUTTON_RELEASE:
        ret = luaH_object_emit_signal(L, -3, "button-release", 2, 1);
        break;
      default:
        ret = luaH_object_emit_signal(L, -3, "button-press", 2, 1);
        break;
    }

    gboolean catch = ret && lua_toboolean(L, -1) ? TRUE : FALSE;
    lua_pop(L, ret + 1);
    return catch;
}

gboolean
focus_cb(GtkWidget* UNUSED(win), GdkEventFocus *ev, widget_t *w)
{
    lua_State *L = globalconf.L;
    luaH_object_push(L, w->ref);
    gint ret;
    if (ev->in)
        ret = luaH_object_emit_signal(L, -1, "focus", 0, 1);
    else
        ret = luaH_object_emit_signal(L, -1, "unfocus", 0, 1);

    /* catch focus event */
    if (ret && lua_toboolean(L, -1)) {
        lua_pop(L, ret + 1);
        return TRUE;
    }

    lua_pop(L, ret + 1);
    /* propagate event further */
    return FALSE;
}

/* gtk container add callback */
void
add_cb(GtkContainer* UNUSED(c), GtkWidget *widget, widget_t *w)
{
    widget_t *child = g_object_get_data(G_OBJECT(widget), "lua_widget");
    lua_State *L = globalconf.L;
    luaH_object_push(L, w->ref);
    luaH_object_push(L, child->ref);
    luaH_object_emit_signal(L, -2, "add", 1, 0);
    lua_pop(L, 1);
}

/* gtk container remove callback */
void
remove_cb(GtkContainer* UNUSED(c), GtkWidget *widget, widget_t *w)
{
    widget_t *child = g_object_get_data(G_OBJECT(widget), "lua_widget");
    lua_State *L = globalconf.L;
    luaH_object_push(L, w->ref);
    luaH_object_push(L, child->ref);
    luaH_object_emit_signal(L, -2, "remove", 1, 0);
    lua_pop(L, 1);
}

void
parent_set_cb(GtkWidget *widget, GtkObject* UNUSED(old), widget_t *w)
{
    lua_State *L = globalconf.L;
    widget_t *parent = NULL;
    GtkContainer *new;
    g_object_get(G_OBJECT(widget), "parent", &new, NULL);
    luaH_object_push(L, w->ref);
    if (new && (parent = g_object_get_data(G_OBJECT(new), "lua_widget")))
        luaH_object_push(L, parent->ref);
    else
        lua_pushnil(L);
    luaH_object_emit_signal(L, -2, "parent-set", 1, 0);
    lua_pop(L, 1);
}

gboolean
true_cb()
{
    return TRUE;
}

/* set child method for gtk container widgets */
gint
luaH_widget_set_child(lua_State *L, widget_t *w)
{
    widget_t *child = luaH_checkwidgetornil(L, 3);

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
luaH_widget_get_child(lua_State *L, widget_t *w)
{
    GtkWidget *widget = gtk_bin_get_child(GTK_BIN(w->widget));

    if (!widget)
        return 0;

    widget_t *child = g_object_get_data(G_OBJECT(w->widget), "lua_widget");
    luaH_object_push(L, child->ref);
    return 1;
}

gint
luaH_widget_remove(lua_State *L)
{
    widget_t *w = luaH_checkwidget(L, 1);
    widget_t *child = luaH_checkwidget(L, 2);
    g_object_ref(G_OBJECT(child->widget));
    gtk_container_remove(GTK_CONTAINER(w->widget), GTK_WIDGET(child->widget));
    return 0;
}

gint
luaH_widget_get_children(lua_State *L, widget_t *w)
{
    widget_t *child;
    GList *children = gtk_container_get_children(GTK_CONTAINER(w->widget));
    GList *iter = children;

    /* push table of the containers children onto the stack */
    lua_newtable(L);
    for (gint i = 1; iter; iter = iter->next) {
        child = g_object_get_data(G_OBJECT(iter->data), "lua_widget");
        luaH_object_push(L, child->ref);
        lua_rawseti(L, -2, i++);
    }
    g_list_free(children);
    return 1;
}

gint
luaH_widget_show(lua_State *L)
{
    widget_t *w = luaH_checkwidget(L, 1);
    gtk_widget_show(w->widget);
    return 0;
}

gint
luaH_widget_hide(lua_State *L)
{
    widget_t *w = luaH_checkwidget(L, 1);
    gtk_widget_hide(w->widget);
    return 0;
}

gint
luaH_widget_focus(lua_State *L)
{
    widget_t *w = luaH_checkwidget(L, 1);
    gtk_widget_grab_focus(w->widget);
    return 0;
}

gint
luaH_widget_destroy(lua_State *L)
{
    widget_t *w = luaH_checkwidget(L, 1);
    if (w->destructor)
        w->destructor(w);
    w->destructor = NULL;
    debug("unreffing widget %p of type '%s'", w, w->info->name);
    luaH_object_unref(L, w->ref);
    return 0;
}

void
widget_destructor(widget_t *w)
{
    debug("destroying widget %p of type '%s'", w, w->info->name);
    if (w->widget)
        gtk_widget_destroy(GTK_WIDGET(w->widget));
    w->widget = NULL;
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
