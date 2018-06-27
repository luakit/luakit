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
    lua_State *L = common.L;
    luaH_object_push(L, w->ref);
    luaH_modifier_table_push(L, ev->state);
    luaH_keystr_push(L, ev->keyval);
    lua_pushboolean(L, ev->send_event);
    gint ret = luaH_object_emit_signal(L, -4, "key-press", 3, 1);
    gboolean catch = ret && lua_toboolean(L, -1) ? TRUE : FALSE;
    lua_pop(L, ret + 1);
    return catch;
}

gboolean
button_cb(GtkWidget* UNUSED(win), GdkEventButton *ev, widget_t *w)
{
    gint ret;
    lua_State *L = common.L;
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
scroll_cb(GtkWidget *UNUSED(wid), GdkEventScroll *ev, widget_t *w)
{
    double dx, dy;
    switch (ev->direction) {
        case GDK_SCROLL_UP:     dx =  0; dy = -1; break;
        case GDK_SCROLL_DOWN:   dx =  0; dy =  1; break;
        case GDK_SCROLL_LEFT:   dx = -1; dy =  0; break;
        case GDK_SCROLL_RIGHT:  dx =  1; dy =  0; break;
        case GDK_SCROLL_SMOOTH: gdk_event_get_scroll_deltas((GdkEvent*)ev, &dx, &dy); break;
        default: g_assert_not_reached();
    }

    lua_State *L = common.L;
    luaH_object_push(L, w->ref);
    luaH_modifier_table_push(L, ev->state);
    lua_pushnumber(L, dx);
    lua_pushnumber(L, dy);

    gboolean ret = luaH_object_emit_signal(L, -4, "scroll", 3, 1);
    lua_pop(L, ret + 1);
    return ret;
}

gboolean
mouse_cb(GtkWidget* UNUSED(win), GdkEventCrossing *ev, widget_t *w)
{
    lua_State *L = common.L;
    luaH_object_push(L, w->ref);
    luaH_modifier_table_push(L, ev->state);

    GdkEventType type = ev->type;
    g_assert(type == GDK_ENTER_NOTIFY || type == GDK_LEAVE_NOTIFY);
    gint ret = luaH_object_emit_signal(L, -2, type == GDK_ENTER_NOTIFY ? "mouse-enter" : "mouse-leave", 1, 1);

    gboolean catch = ret && lua_toboolean(L, -1) ? TRUE : FALSE;
    lua_pop(L, ret + 1);
    return catch;
}

gboolean
focus_cb(GtkWidget* UNUSED(win), GdkEventFocus *ev, widget_t *w)
{
    lua_State *L = common.L;
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
    widget_t *child = GOBJECT_TO_LUAKIT_WIDGET(widget);
    lua_State *L = common.L;
    luaH_object_push(L, w->ref);
    luaH_object_push(L, child->ref);
    luaH_object_emit_signal(L, -2, "add", 1, 0);
    lua_pop(L, 1);
}

void
resize_cb(GtkWidget* UNUSED(win), GdkRectangle *rect, widget_t *w)
{
    int width = rect->width, height = rect->height;
    if (width == w->prev_width && height == w->prev_height)
        return;
    w->prev_width = width;
    w->prev_height = height;

    lua_State *L = common.L;
    luaH_object_push(L, w->ref);
    lua_pushinteger(L, width);
    lua_pushinteger(L, height);
    luaH_object_emit_signal(L, -3, "resize", 2, 0);
    lua_pop(L, 1);
}

/* gtk container remove callback */
void
remove_cb(GtkContainer* UNUSED(c), GtkWidget *widget, widget_t *w)
{
    widget_t *child = GOBJECT_TO_LUAKIT_WIDGET(widget);
    lua_State *L = common.L;
    luaH_object_push(L, w->ref);
    luaH_object_push(L, child->ref);
    luaH_object_emit_signal(L, -2, "remove", 1, 0);
    lua_pop(L, 1);
}

void
parent_set_cb(GtkWidget *widget, GtkWidget *UNUSED(p), widget_t *w)
{
    lua_State *L = common.L;
    widget_t *parent = NULL;
    GtkContainer *new;
    g_object_get(G_OBJECT(widget), "parent", &new, NULL);
    luaH_object_push(L, w->ref);
    if (new && (parent = GOBJECT_TO_LUAKIT_WIDGET(new)))
        luaH_object_push(L, parent->ref);
    else
        lua_pushnil(L);
    luaH_object_emit_signal(L, -2, "parent-set", 1, 0);
    lua_pop(L, 1);
}

void
destroy_cb(GtkWidget* UNUSED(win), widget_t *w)
{
    /* 1. emit destroy signal */
    lua_State *L = common.L;
    luaH_object_push(L, w->ref);
    luaH_object_emit_signal(L, -1, "destroy", 0, 0);
    lua_pop(L, 1);

    /* 2. Call widget destructor */
    debug("destroy %p (%s)", w, w->info->name);
    if (w->destructor)
        w->destructor(w);
    w->destructor = NULL;
    w->widget = NULL;

    /* 3. Allow this Lua instance to be freed */
    luaH_object_unref(L, w->ref);
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

    widget_t *child = GOBJECT_TO_LUAKIT_WIDGET(widget);
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
    if (!GTK_IS_CONTAINER(w->widget))
        return 0;

    GList *children = gtk_container_get_children(GTK_CONTAINER(w->widget));
    GList *iter = children;

    /* push table of the containers children onto the stack */
    lua_newtable(L);
    for (gint i = 1; iter; iter = iter->next) {
        luaH_object_push(L, GOBJECT_TO_LUAKIT_WIDGET(iter->data)->ref);
        lua_rawseti(L, -2, i++);
    }
    g_list_free(children);
    return 1;
}

gint
luaH_widget_replace(lua_State *L)
{
    widget_t *och = luaH_checkwidget(L, 1);
    widget_t *nch = luaH_checkwidget(L, 2);

    GtkWidget *parent = gtk_widget_get_parent(GTK_WIDGET(och->widget));
    if (!parent)
        return 0;

    guint num_props;
    GParamSpec **props = gtk_container_class_list_child_properties(
            G_OBJECT_GET_CLASS(parent), &num_props);

    GValue *values = g_new0(GValue, num_props);
    for (guint i = 0; i < num_props; i++)
    {
        g_value_init(&values[i], G_PARAM_SPEC_VALUE_TYPE(props[i]));
        gtk_container_child_get_property(GTK_CONTAINER(parent),
                GTK_WIDGET(och->widget), props[i]->name, &values[i]);
    }

    g_object_ref(G_OBJECT(och->widget));
    gtk_container_remove(GTK_CONTAINER(parent), GTK_WIDGET(och->widget));

    gtk_container_add(GTK_CONTAINER(parent), GTK_WIDGET(nch->widget));
    for (guint i = 0; i < num_props; i++)
    {
        gtk_container_child_set_property(GTK_CONTAINER(parent),
                GTK_WIDGET(nch->widget), props[i]->name, &values[i]);
        g_value_unset(&values[i]);
    }

    g_free(props);
    g_free(values);
    return 0;
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
luaH_widget_send_key(lua_State *L)
{
    widget_t *w = luaH_checkwidget(L, 1);
    const gchar *key_name = luaL_checkstring(L, 2);
    if (!lua_istable(L, 3))
    {
        lua_newtable(L);
        lua_insert(L, 3);
    }
    const gboolean is_release = lua_toboolean(L, 4);

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

    GdkEvent *event = gdk_event_new(is_release ? GDK_KEY_RELEASE : GDK_KEY_PRESS);
    GdkEventKey *event_key = (GdkEventKey *) event;
    event_key->window = gtk_widget_get_window(w->widget);
    event_key->send_event = FALSE;
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

    gboolean ret;
    debug("sending key '%s%s' to widget %p", state_string->str, key_name, w->widget);
    g_signal_emit_by_name(w->widget, is_release ? "key-release-event" : "key-press-event", event, &ret);

    g_string_free(state_string, TRUE);
    g_free(keys);
    return 0;
}

gint
luaH_widget_set_visible(lua_State *L, widget_t *w)
{
    gboolean visible = luaH_checkboolean(L, 3);
    gtk_widget_set_visible(w->widget, visible);
    if (visible && w->info->tok == L_TK_WINDOW)
        gdk_window_set_events(gtk_widget_get_window(w->widget),
                GDK_ALL_EVENTS_MASK);
    return 0;
}

gint
luaH_widget_get_min_size(lua_State *L, widget_t *w)
{
    gint width, height;
    gtk_widget_get_size_request(w->widget, &width, &height);

    lua_newtable(L);

    lua_pushliteral(L, "width");
    lua_pushinteger(L, width);
    lua_rawset(L, -3);

    lua_pushliteral(L, "height");
    lua_pushinteger(L, height);
    lua_rawset(L, -3);

    return 1;
}

gint
luaH_widget_set_min_size(lua_State *L, widget_t *w)
{
    luaH_checktable(L, 3);

    gint width, height;
    gtk_widget_get_size_request(w->widget, &width, &height);

    gint top = lua_gettop(L);
    if (luaH_rawfield(L, 3, "w"))
        width = lua_tonumber(L, -1);
    if (luaH_rawfield(L, 3, "h"))
        height = lua_tonumber(L, -1);
    lua_settop(L, top);

    gtk_widget_set_size_request(w->widget, width, height);
    return 1;
}

gint
luaH_widget_get_align(lua_State *L, widget_t *w)
{
    GtkAlign halign = gtk_widget_get_halign(GTK_WIDGET(w->widget)),
             valign = gtk_widget_get_valign_with_baseline(GTK_WIDGET(w->widget));
    lua_createtable(L, 0, 2);
    /* set align.h */
    lua_pushliteral(L, "h");
    lua_pushnumber(L, halign);
    lua_rawset(L, -3);
    /* set align.v */
    lua_pushliteral(L, "v");
    lua_pushnumber(L, valign);
    lua_rawset(L, -3);
    return 1;
}

gint
luaH_widget_set_align(lua_State *L, widget_t *w)
{
    luaH_checktable(L, 3);
    GtkAlign halign = gtk_widget_get_halign(GTK_WIDGET(w->widget)),
             valign = gtk_widget_get_valign_with_baseline(GTK_WIDGET(w->widget));
    if (luaH_rawfield(L, 3, "h"))
        switch (l_tokenize(lua_tostring(L, -1))) {
            case L_TK_FILL:     halign = GTK_ALIGN_FILL;     break;
            case L_TK_START:    halign = GTK_ALIGN_START;    break;
            case L_TK_END:      halign = GTK_ALIGN_END;      break;
            case L_TK_CENTER:   halign = GTK_ALIGN_CENTER;   break;
            case L_TK_BASELINE: halign = GTK_ALIGN_BASELINE; break;
            default:
                return luaL_error(L, "Bad alignment value (expected fill, start, end, center, or baseline)");
        }
    if (luaH_rawfield(L, 3, "v"))
        switch (l_tokenize(lua_tostring(L, -1))) {
            case L_TK_FILL:     valign = GTK_ALIGN_FILL;     break;
            case L_TK_START:    valign = GTK_ALIGN_START;    break;
            case L_TK_END:      valign = GTK_ALIGN_END;      break;
            case L_TK_CENTER:   valign = GTK_ALIGN_CENTER;   break;
            case L_TK_BASELINE: valign = GTK_ALIGN_BASELINE; break;
            default:
                return luaL_error(L, "Bad alignment value (expected fill, start, end, center, or baseline)");
        }
    gtk_widget_set_halign(GTK_WIDGET(w->widget), halign);
    gtk_widget_set_valign(GTK_WIDGET(w->widget), valign);
    return 0;
}

gint
luaH_widget_set_tooltip(lua_State *L, widget_t *w)
{
    gtk_widget_set_tooltip_markup(w->widget, lua_tostring(L, 3) ?: "");
    return 0;
}

gint
luaH_widget_get_tooltip(lua_State *L, widget_t *w)
{
    lua_pushstring(L, gtk_widget_get_tooltip_markup(w->widget));
    return 1;
}

gint
luaH_widget_get_parent(lua_State *L, widget_t *w)
{
    GtkWidget *widget = gtk_widget_get_parent(GTK_WIDGET(w->widget));

    if (!widget)
        return 0;

    widget_t *parent = GOBJECT_TO_LUAKIT_WIDGET(widget);
    luaH_object_push(L, parent->ref);
    return 1;
}

gint
luaH_widget_get_focused(lua_State *L, widget_t *w)
{
    gboolean focused = w->info->tok == L_TK_WINDOW ?
        gtk_window_has_toplevel_focus(GTK_WINDOW(w->widget)) :
        gtk_widget_is_focus(w->widget);
    lua_pushboolean(L, focused);
    return 1;
}

gint
luaH_widget_get_visible(lua_State *L, widget_t *w)
{
    lua_pushboolean(L, gtk_widget_get_visible(w->widget));
    return 1;
}

gint
luaH_widget_get_width(lua_State *L, widget_t *w)
{
    lua_pushnumber(L, gtk_widget_get_allocated_width(w->widget));
    return 1;
}

gint
luaH_widget_get_height(lua_State *L, widget_t *w)
{
    lua_pushnumber(L, gtk_widget_get_allocated_height(w->widget));
    return 1;
}

gint
luaH_widget_focus(lua_State *L)
{
    widget_t *w = luaH_checkwidget(L, 1);

    switch (w->info->tok) {
        case L_TK_WINDOW:
            /* win:focus() unfocuses anything within that window */
            gtk_window_set_focus(GTK_WINDOW(w->widget), NULL);
            break;
        case L_TK_ENTRY:
            gtk_entry_grab_focus_without_selecting(GTK_ENTRY(w->widget));
            break;
        default:
            gtk_widget_grab_focus(w->widget);
            break;
    }

    return 0;
}

gint
luaH_widget_destroy(lua_State *L)
{
    widget_t *w = luaH_checkwidget(L, 1);
    gtk_widget_destroy(GTK_WIDGET(w->widget));
    return 0;
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
