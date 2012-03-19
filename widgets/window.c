/*
 * widgets/window.c - gtk window widget wrapper
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

#include <gdk/gdkx.h>
#include "luah.h"
#include "widgets/common.h"
#include "clib/soup/auth.h"

typedef struct {
    widget_t *widget;
    GtkWindow *win;
    GdkWindowState state;
} window_data_t;

static widget_t *
luaH_checkwindow(lua_State *L, gint udx)
{
    widget_t *w = luaH_checkwidget(L, udx);
    if (w->info->tok != L_TK_WINDOW)
        luaL_argerror(L, udx, "expected window widget");
    return w;
}

#define luaH_checkwindata(L, udx) ((window_data_t*)(luaH_checkwindow(L, udx)->data))

static void
destroy_cb(GtkObject* UNUSED(win), widget_t *w)
{
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
    window_data_t *d = luaH_checkwindata(L, 1);
    gint width = (gint) luaL_checknumber(L, 2);
    gint height = (gint) luaL_checknumber(L, 3);
    gtk_window_set_default_size(d->win, width, height);
    return 0;
}

static gint
luaH_window_index(lua_State *L, widget_t *w, luakit_token_t token)
{
    window_data_t *d = w->data;

    switch(token) {
      LUAKIT_WIDGET_INDEX_COMMON(w)
      LUAKIT_WIDGET_BIN_INDEX_COMMON(w)
      LUAKIT_WIDGET_CONTAINER_INDEX_COMMON(w)

      /* push window class methods */
      PF_CASE(SET_DEFAULT_SIZE, luaH_window_set_default_size)

      /* push string properties */
      PS_CASE(TITLE, gtk_window_get_title(d->win))

      /* push boolean properties */
      PB_CASE(DECORATED,    gtk_window_get_decorated(d->win))
      PB_CASE(URGENCY_HINT, gtk_window_get_urgency_hint(d->win))
      PB_CASE(FULLSCREEN,   d->state & GDK_WINDOW_STATE_FULLSCREEN)
      PB_CASE(MAXIMIZED,    d->state & GDK_WINDOW_STATE_MAXIMIZED)

      /* push integer properties */
      PI_CASE(XID, GDK_WINDOW_XID(GTK_WIDGET(d->win)->window))

      case L_TK_SCREEN:
        lua_pushlightuserdata(L, gtk_window_get_screen(d->win));
        return 1;

      default:
        break;
    }
    return 0;
}

static gint
luaH_window_newindex(lua_State *L, widget_t *w, luakit_token_t token)
{
    window_data_t *d = w->data;

    switch(token) {
      LUAKIT_WIDGET_NEWINDEX_COMMON(w)
      LUAKIT_WIDGET_BIN_NEWINDEX_COMMON(w)

      case L_TK_DECORATED:
        gtk_window_set_decorated(d->win, luaH_checkboolean(L, 3));
        break;

      case L_TK_URGENCY_HINT:
        gtk_window_set_urgency_hint(d->win, luaH_checkboolean(L, 3));
        break;

      case L_TK_TITLE:
        gtk_window_set_title(d->win, luaL_checkstring(L, 3));
        break;

      case L_TK_ICON:
        gtk_window_set_icon_from_file(d->win, luaL_checkstring(L, 3), NULL);
        break;

      case L_TK_SCREEN:
        if (!lua_islightuserdata(L, 3))
            luaL_argerror(L, 3, "expected GdkScreen lightuserdata");
        gtk_window_set_screen(d->win, (GdkScreen*)lua_touserdata(L, 3));
        gtk_window_present(d->win);
        break;

      case L_TK_FULLSCREEN:
        if (luaH_checkboolean(L, 3))
            gtk_window_fullscreen(d->win);
        else
            gtk_window_unfullscreen(d->win);
        return 0;

      case L_TK_MAXIMIZED:
        if (luaH_checkboolean(L, 3))
            gtk_window_maximize(d->win);
        else
            gtk_window_unmaximize(d->win);
        return 0;

      default:
        return 0;
    }

    return luaH_object_property_signal(L, 1, token);
}

static gboolean
window_state_cb(GtkWidget* UNUSED(widget), GdkEventWindowState *ev, widget_t *w)
{
    window_data_t *d = (window_data_t*)w->data;
    d->state = ev->new_window_state;
    lua_State *L = globalconf.L;
    luaH_object_push(L, w->ref);

    if (ev->changed_mask & GDK_WINDOW_STATE_MAXIMIZED)
        luaH_object_property_signal(L, -1, L_TK_MAXIMIZED);

    if (ev->changed_mask & GDK_WINDOW_STATE_FULLSCREEN)
        luaH_object_property_signal(L, -1, L_TK_FULLSCREEN);

    lua_pop(L, 1);
    return FALSE;
}

static void
window_destructor(widget_t *w)
{
    g_slice_free(window_data_t, w->data);
    widget_destructor(w);
}

widget_t *
widget_window(widget_t *w, luakit_token_t UNUSED(token))
{
    w->index = luaH_window_index;
    w->newindex = luaH_window_newindex;
    w->destructor = window_destructor;

    /* create private window data struct */
    window_data_t *d = g_slice_new0(window_data_t);
    d->widget = w;
    w->data = d;

    /* create and setup window widget */
    w->widget = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    d->win = GTK_WINDOW(w->widget);
    gtk_window_set_wmclass(d->win, "luakit", "luakit");
    gtk_window_set_default_size(d->win, 800, 600);
    gtk_window_set_title(d->win, "luakit");

    GdkGeometry hints;
    hints.min_width = 1;
    hints.min_height = 1;
    gtk_window_set_geometry_hints(d->win, NULL, &hints, GDK_HINT_MIN_SIZE);

    g_object_connect(G_OBJECT(w->widget),
      LUAKIT_WIDGET_SIGNAL_COMMON(w)
      "signal::add",                G_CALLBACK(add_cb),          w,
      "signal::destroy",            G_CALLBACK(destroy_cb),      w,
      "signal::key-press-event",    G_CALLBACK(key_press_cb),    w,
      "signal::remove",             G_CALLBACK(remove_cb),       w,
      "signal::window-state-event", G_CALLBACK(window_state_cb), w,
      NULL);

    /* add to global windows list */
    g_ptr_array_add(globalconf.windows, w);

    return w;
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
