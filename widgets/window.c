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
#include <gdk/gdkkeysyms.h>
#include "luah.h"
#include "widgets/common.h"

typedef struct {
    widget_t *widget;
    GtkWindow *win;
    GdkWindowState state;
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

static gint
can_close_cb(GtkWidget* UNUSED(win), GdkEvent *UNUSED(event), widget_t *w)
{
    lua_State *L = common.L;
    luaH_object_push(L, w->ref);
    gint ret = luaH_object_emit_signal(L, -1, "can-close", 0, 1);
    gboolean keep_open = ret && !lua_toboolean(L, -1);
    lua_pop(L, ret + 1);
    return keep_open;
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
luaH_window_send_key(lua_State *L)
{
    widget_t *w = luaH_checkwidget(L, 1);
    const gchar *key_name = luaL_checkstring(L, 2);
    if (lua_gettop(L) >= 3)
        luaH_checktable(L, 3);
    else
        lua_newtable(L);

    if (!g_utf8_validate(key_name, -1, NULL))
        return luaL_error(L, "key name isn't a utf-8 string");

    guint keyval;
    if (g_utf8_strlen(key_name, -1) == 1)
        keyval = gdk_unicode_to_keyval(g_utf8_get_char(key_name));
    else
        keyval = gdk_keyval_from_name(key_name);

    if (!keyval || keyval == GDK_KEY_VoidSymbol)
        return luaL_error(L, "failed to get a valid key value");

    guint state = 0;
    GString *state_string = g_string_sized_new(32);
    lua_pushnil(L);
    while (lua_next(L, 3)) {
        const gchar *mod = luaL_checkstring(L, -1);
        g_string_append_printf(state_string, "%s-", mod);

#define MODKEY(modstr, modconst) \
        if (strcmp(modstr, mod) == 0) { \
            state = state | GDK_##modconst##_MASK; \
        }

        MODKEY("shift", SHIFT);
        MODKEY("control", CONTROL);
        MODKEY("lock", LOCK);
        MODKEY("mod1", MOD1);
        MODKEY("mod2", MOD2);
        MODKEY("mod3", MOD3);
        MODKEY("mod4", MOD4);
        MODKEY("mod5", MOD5);

#undef MODKEY

        lua_pop(L, 1);
    }

    GdkKeymapKey *keys = NULL;
    gint n_keys;
    if (!gdk_keymap_get_entries_for_keyval(gdk_keymap_get_default(),
                                           keyval, &keys, &n_keys)) {
        g_string_free(state_string, TRUE);
        return luaL_error(L, "cannot type '%s' on current keyboard layout",
                          key_name);
    }

    GdkEvent *event = gdk_event_new(GDK_KEY_PRESS);
    GdkEventKey *event_key = (GdkEventKey *) event;
    event_key->window = gtk_widget_get_window(w->widget);
    event_key->send_event = TRUE;
    event_key->time = GDK_CURRENT_TIME;
    event_key->state = state;
    event_key->keyval = keyval;
    event_key->hardware_keycode = keys[0].keycode;
    event_key->group = keys[0].group;

    GdkDevice *kbd = NULL;
#if GTK_CHECK_VERSION(3,20,0)
    GdkSeat *seat = gdk_display_get_default_seat(gdk_display_get_default());
    kbd = gdk_seat_get_keyboard(seat);
#else
    GdkDeviceManager *dev_mgr = gdk_display_get_device_manager(gdk_display_get_default());
    GList *devices = gdk_device_manager_list_devices(dev_mgr, GDK_DEVICE_TYPE_MASTER);
    for (GList *dev = devices; dev && !kbd; dev = dev->next)
        if (gdk_device_get_source(dev->data) == GDK_SOURCE_KEYBOARD)
            kbd = dev->data;
    g_list_free(devices);
#endif
    if (!kbd)
        return luaL_error(L, "failed to find a keyboard device");
    gdk_event_set_device(event, kbd);

    gdk_event_put(event);
    debug("sending key '%s%s' to window %p", state_string->str, key_name, w);

    g_string_free(state_string, TRUE);
    g_free(keys);
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
      PF_CASE(SEND_KEY,         luaH_window_send_key)

      /* push string properties */
      PS_CASE(TITLE, gtk_window_get_title(d->win))

      /* push boolean properties */
      PB_CASE(DECORATED,    gtk_window_get_decorated(d->win))
      PB_CASE(URGENCY_HINT, gtk_window_get_urgency_hint(d->win))
      PB_CASE(FULLSCREEN,   d->state & GDK_WINDOW_STATE_FULLSCREEN)
      PB_CASE(MAXIMIZED,    d->state & GDK_WINDOW_STATE_MAXIMIZED)

      /* push integer properties */
      PN_CASE(ID,           d->id)

# ifdef GDK_WINDOWING_X11
      case L_TK_ROOT_WIN_XID:
        lua_pushinteger(L, GDK_WINDOW_XID(
#  if GTK_CHECK_VERSION(3,12,0)
                gdk_screen_get_root_window(gtk_widget_get_screen(GTK_WIDGET(d->win)))
#  else
                gtk_widget_get_root_window(GTK_WIDGET(d->win))
#  endif
        ));
        return 1;

      PI_CASE(WIN_XID, GDK_WINDOW_XID(gtk_widget_get_window(GTK_WIDGET(d->win))));
# endif

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
    lua_State *L = common.L;
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
    w->widget = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    d->win = GTK_WINDOW(w->widget);
    gtk_window_set_default_size(d->win, 800, 600);
    gtk_window_set_title(d->win, "luakit");
    if (globalconf.application)
        gtk_window_set_application(d->win, globalconf.application);

    GdkGeometry hints;
    hints.min_width = 1;
    hints.min_height = 1;
    gtk_window_set_geometry_hints(d->win, NULL, &hints, GDK_HINT_MIN_SIZE);

    g_object_connect(G_OBJECT(w->widget),
      "signal::destroy",            G_CALLBACK(destroy_win_cb),  w,
      LUAKIT_WIDGET_SIGNAL_COMMON(w)
      "signal::add",                G_CALLBACK(add_cb),          w,
      "signal::delete-event",       G_CALLBACK(can_close_cb),    w,
      "signal::key-press-event",    G_CALLBACK(key_press_cb),    w,
      "signal::remove",             G_CALLBACK(remove_cb),       w,
      "signal::window-state-event", G_CALLBACK(window_state_cb), w,
      NULL);

    d->id = ++window_id_next;

    /* add to global windows list */
    g_ptr_array_add(globalconf.windows, w);

    return w;
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
