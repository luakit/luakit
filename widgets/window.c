/*
 * widgets/window.c - gtk window widget wrapper
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

#include <gdk/gdkx.h>
#include "luah.h"
#include "widgets/common.h"
#include "classes/soup/auth.h"

static void
destroy_cb(GtkObject *win, widget_t *w)
{
    (void) win;

    /* remove window from global windows list */
    g_ptr_array_remove(globalconf.windows, w);

    lua_State *L = globalconf.L;
    luaH_object_push(L, w->ref);
    luaH_object_emit_signal(L, -1, "destroy", 0, 0);
    lua_pop(L, 1);
}

static gint
luaH_window_set_default_size(lua_State *L)
{
    widget_t *w = luaH_checkwidget(L, 1);
    gint width = (gint) luaL_checknumber(L, 2);
    gint height = (gint) luaL_checknumber(L, 3);
    gtk_window_set_default_size(GTK_WINDOW(w->widget), width, height);
    return 0;
}

static gint
luaH_window_show(lua_State *L)
{
    widget_t *w = luaH_checkwidget(L, 1);
    gtk_widget_show(w->widget);
    gdk_window_set_events(gtk_widget_get_window(w->widget), GDK_ALL_EVENTS_MASK);
    return 0;
}

static gint
luaH_window_index(lua_State *L, luakit_token_t token)
{
    widget_t *w = luaH_checkwidget(L, 1);

    switch(token)
    {
      LUAKIT_WIDGET_BIN_INDEX_COMMON
      LUAKIT_WIDGET_CONTAINER_INDEX_COMMON

      /* push widget class methods */
      PF_CASE(DESTROY, luaH_widget_destroy)
      PF_CASE(FOCUS,   luaH_widget_focus)
      PF_CASE(HIDE,    luaH_widget_hide)

      /* push window class methods */
      PF_CASE(SET_DEFAULT_SIZE, luaH_window_set_default_size)
      PF_CASE(SHOW,             luaH_window_show)

      /* push string methods */
      PS_CASE(TITLE, gtk_window_get_title(GTK_WINDOW(w->widget)))

      case L_TK_XID:
        lua_pushnumber(L, GDK_WINDOW_XID(GTK_WIDGET(w->widget)->window));
        return 1;

      default:
        break;
    }
    return 0;
}

static gint
luaH_window_newindex(lua_State *L, luakit_token_t token)
{
    size_t len;
    widget_t *w = luaH_checkwidget(L, 1);

    switch(token)
    {
      case L_TK_TITLE:
        gtk_window_set_title(GTK_WINDOW(w->widget),
            luaL_checklstring(L, 3, &len));
        break;

      case L_TK_ICON:
        gtk_window_set_icon_from_file(GTK_WINDOW(w->widget),
            luaL_checklstring(L, 3, &len), NULL);
        break;

      default:
        return 0;
    }

    return luaH_object_emit_property_signal(L, 1);
}

widget_t *
widget_window(widget_t *w)
{
    w->index = luaH_window_index;
    w->newindex = luaH_window_newindex;
    w->destructor = widget_destructor;

    /* create and setup window widget */
    w->widget = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    g_object_set_data(G_OBJECT(w->widget), "lua_widget", (gpointer) w);
    gtk_window_set_wmclass(GTK_WINDOW(w->widget), "luakit", "luakit");
    gtk_window_set_default_size(GTK_WINDOW(w->widget), 800, 600);
    gtk_window_set_title(GTK_WINDOW(w->widget), "luakit");
    GdkGeometry hints;
    hints.min_width = 1;
    hints.min_height = 1;
    gtk_window_set_geometry_hints(GTK_WINDOW(w->widget), NULL, &hints, GDK_HINT_MIN_SIZE);

    g_object_connect(G_OBJECT(w->widget),
      "signal::add",             G_CALLBACK(add_cb),       w,
      "signal::destroy",         G_CALLBACK(destroy_cb),   w,
      "signal::key-press-event", G_CALLBACK(key_press_cb), w,
      "signal::remove",          G_CALLBACK(remove_cb),    w,
      NULL);

    /* add to global windows list */
    g_ptr_array_add(globalconf.windows, w);

    return w;
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
