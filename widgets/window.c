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

#include <gdk/gdk.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/x11/gdkx.h>
#endif

#include "luah.h"
#include "widgets/common.h"

typedef struct {
    widget_t *widget;
    GtkWindow *win;
    guint id;
} window_data_t;

static int window_id_next = 0;

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
destroy_win_cb(GtkWidget* UNUSED(win), widget_t *w)
{
    /* remove window from global windows list */
    g_ptr_array_remove(globalconf.windows, w);
}

static gboolean
close_request_cb(GtkWindow *UNUSED(win), widget_t *w)
{
    lua_State *L = common.L;
    luaH_object_push(L, w->ref);
    gint ret = luaH_object_emit_signal(L, -1, "can-close", 0, 1);
    gboolean keep_open = ret && !lua_toboolean(L, -1);
    lua_pop(L, ret + 1);
    return keep_open;
}

static void
window_maximized_cb(GObject *object, GParamSpec *UNUSED(pspec), widget_t *w)
{
    lua_State *L = common.L;
    luaH_object_push(L, w->ref);
    luaH_object_property_signal(L, -1, L_TK_MAXIMIZED);
    lua_pop(L, 1);
}

static void
window_fullscreen_cb(GObject *object, GParamSpec *UNUSED(pspec), widget_t *w)
{
    lua_State *L = common.L;
    luaH_object_push(L, w->ref);
    luaH_object_property_signal(L, -1, L_TK_FULLSCREEN);
    lua_pop(L, 1);
}

static gint
luaH_window_set_dark_mode(lua_State *L)
{
   window_data_t *d = luaH_checkwindata(L, 1);
   gboolean dark_mode = lua_toboolean(L, 2);
   g_object_set(gtk_widget_get_settings(GTK_WIDGET(d->win)),
           "gtk-application-prefer-dark-theme", dark_mode, NULL);
    return 0;
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

gint
luaH_window_destroy(lua_State *L)
{
    widget_t *w = luaH_checkwidget(L, 1);
    gtk_window_destroy(GTK_WINDOW(w->widget));
    return 0;
}

static gint
luaH_window_index(lua_State *L, widget_t *w, luakit_token_t token)
{
    window_data_t *d = w->data;

    switch(token) {
      LUAKIT_WIDGET_INDEX_COMMON(w)
      LUAKIT_WIDGET_CHILD_INDEX_COMMON(w)

      /* push window class methods */
      PF_CASE(DESTROY,      luaH_window_destroy)
      PF_CASE(SET_DEFAULT_SIZE, luaH_window_set_default_size)
      PF_CASE(SET_DARK_MODE, luaH_window_set_dark_mode)

      /* push string properties */
      PS_CASE(TITLE, gtk_window_get_title(d->win))

      /* push boolean properties */
      PB_CASE(DECORATED,     gtk_window_get_decorated(d->win))
      PB_CASE(URGENCY_HINT,  FALSE)
      PB_CASE(FULLSCREEN,    gtk_window_is_fullscreen(d->win))
      PB_CASE(MAXIMIZED,     gtk_window_is_maximized(d->win))

      /* push integer properties */
      PN_CASE(ID,           d->id)

# ifdef GDK_WINDOWING_X11
      case L_TK_ROOT_WIN_XID: {
        GdkDisplay *display = gtk_widget_get_display(GTK_WIDGET(d->win));
        if (display && GDK_IS_X11_DISPLAY(display)) {
            Display *xdisplay = gdk_x11_display_get_xdisplay(display);
            int screen = DefaultScreen(xdisplay);
            lua_pushlightuserdata(L, (void*)(uintptr_t)RootWindow(xdisplay, screen));
            return 1;
        }
        break;
      }

      case L_TK_WIN_XID: {
        GdkSurface *surface = gtk_native_get_surface(gtk_widget_get_native(GTK_WIDGET(d->win)));
        if (surface && GDK_IS_X11_SURFACE(surface)) {
            lua_pushlightuserdata(L, (void*)(uintptr_t)gdk_x11_surface_get_xid(surface));
            return 1;
        }
        break;
      }
# endif

      case L_TK_DISPLAY:
        lua_pushlightuserdata(L, gtk_widget_get_display(GTK_WIDGET(d->win)));
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
      LUAKIT_WIDGET_CHILD_NEWINDEX_COMMON(w)

      case L_TK_DECORATED:
        gtk_window_set_decorated(d->win, luaH_checkboolean(L, 3));
        break;

      case L_TK_URGENCY_HINT:
        /* gtk_window_set_urgency_hint is removed in GTK4 */
        // TODO: can be replaced by notification or similar
        break;

      case L_TK_TITLE:
        gtk_window_set_title(d->win, luaL_checkstring(L, 3));
        break;

      case L_TK_ICON:
        /* gtk_window_set_icon_from_file is removed in GTK4 */
        gtk_window_set_icon_name(GTK_WINDOW(d->win), luaL_checkstring(L, 3));
        break;

      case L_TK_DISPLAY:
        if (!lua_islightuserdata(L, 3))
            luaL_argerror(L, 3, "expected GdkDisplay lightuserdata");
        gtk_window_set_display(d->win, (GdkDisplay*)lua_touserdata(L, 3));
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



static void
window_surface_size_changed_cb(GdkSurface *surface, GParamSpec *UNUSED(pspec), widget_t *w)
{
    int width = gdk_surface_get_width(surface);
    int height = gdk_surface_get_height(surface);

    if (width == w->prev_width && height == w->prev_height)
        return;
    w->prev_width = width;
    w->prev_height = height;

    lua_State *L = common.L;
    luaH_object_push(L, w->ref);
    if (lua_isnil(L, -1)) {
        lua_pop(L, 1);
    } else {
        lua_pushinteger(L, width);
        lua_pushinteger(L, height);
        luaH_object_emit_signal(L, -3, "resize", 2, 0);
        lua_pop(L, 1);
    }

    /* Also notify all webviews! */
    if (globalconf.webviews) {
        for (guint i = 0; i < globalconf.webviews->len; ++i) {
            widget_t *wv = g_ptr_array_index(globalconf.webviews, i);
            if (wv->widget && gtk_widget_get_realized(wv->widget)) {
                GtkAllocation alloc;
                gtk_widget_get_allocation(wv->widget, &alloc);
                if (alloc.width > 0 && alloc.height > 0) {
                    if (alloc.width != wv->prev_width || alloc.height != wv->prev_height) {
                        wv->prev_width = alloc.width;
                        wv->prev_height = alloc.height;
                        luaH_object_push(L, wv->ref);
                        if (lua_isnil(L, -1)) {
                            lua_pop(L, 1);
                        } else {
                            lua_pushinteger(L, alloc.width);
                            lua_pushinteger(L, alloc.height);
                            luaH_object_emit_signal(L, -3, "resize", 2, 0);
                            lua_pop(L, 1);
                        }
                    }
                }
            }
        }
    }
}

static void
window_realize_cb(GtkWidget *widget, widget_t *w)
{
    GdkSurface *surface = gtk_native_get_surface(gtk_widget_get_native(widget));
    if (surface) {
        g_signal_connect(surface, "notify::width", G_CALLBACK(window_surface_size_changed_cb), w);
        g_signal_connect(surface, "notify::height", G_CALLBACK(window_surface_size_changed_cb), w);
        window_surface_size_changed_cb(surface, NULL, w);
    }
}

static void
window_destructor(widget_t *w)
{
    g_slice_free(window_data_t, w->data);
}

widget_t *
widget_window(lua_State *UNUSED(L), widget_t *w, luakit_token_t UNUSED(token))
{
    w->index = luaH_window_index;
    w->newindex = luaH_window_newindex;
    w->destructor = window_destructor;

    /* create private window data struct */
    window_data_t *d = g_slice_new0(window_data_t);
    d->widget = w;
    w->data = d;

    /* create and setup window widget */
    w->widget = gtk_window_new();
    d->win = GTK_WINDOW(w->widget);
    gtk_window_set_default_size(d->win, 800, 600);
    gtk_window_set_title(d->win, "luakit");
    if (globalconf.application)
        gtk_window_set_application(d->win, globalconf.application);

    g_signal_connect(w->widget, "destroy", G_CALLBACK(destroy_win_cb), w);

    g_object_connect(G_OBJECT(w->widget),
      LUAKIT_WIDGET_SIGNAL_COMMON(w)
      "signal::notify::parent",     G_CALLBACK(parent_changed_cb), w,
      "signal::realize",            G_CALLBACK(window_realize_cb),  w,
      "signal::notify::child",      G_CALLBACK(child_changed_cb), w,
      "signal::close-request",      G_CALLBACK(close_request_cb), w,
      "signal::notify::maximized",  G_CALLBACK(window_maximized_cb), w,
      "signal::notify::fullscreened", G_CALLBACK(window_fullscreen_cb), w,
      NULL);

    LUAKIT_EVENT_CONTROLLER_KEY(GTK_WIDGET(w->widget), w)
    gtk_event_controller_set_propagation_phase(key_controller, GTK_PHASE_CAPTURE);

    d->id = ++window_id_next;

    /* add to global windows list */
    g_ptr_array_add(globalconf.windows, w);

    return w;
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
