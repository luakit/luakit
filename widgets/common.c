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

#include "clib/widget.h"
#include "common/tokenize.h"
#include "glib.h"
#include "luah.h"
#include "globalconf.h"
#include "common/luaobject.h"
#include "common/lualib.h"
#include "widgets/common.h"
#include "widgets/webview.h"

gboolean
key_press_cb(GtkEventControllerKey *UNUSED(controller), guint keyval, guint UNUSED(keycode),
    GdkModifierType state, widget_t *w)
{
  if (GTK_IS_WINDOW(w->widget)) {
      GtkWidget *focused = gtk_window_get_focus(GTK_WINDOW(w->widget));
      if (focused && globalconf.webviews) {
          for (guint i = 0; i < globalconf.webviews->len; ++i) {
              widget_t *wv = g_ptr_array_index(globalconf.webviews, i);
              if (webview_widget_is_inspector(wv, focused)) {
                  return FALSE;
              }
          }
      }
  }

  lua_State *L = common.L;
  luaH_object_push(L, w->ref);
  luaH_modifier_table_push(L, state);
  luaH_keystr_push(L, keyval);
  gint ret = luaH_object_emit_signal(L, -3, "key-press", 2, 1);
  gboolean catch = ret && lua_toboolean(L, -1) ? TRUE : FALSE;
  lua_pop(L, ret + 1);
  return catch;
}

void
button_pressed_cb(GtkGestureClick *gesture, int n_press, double UNUSED(x), double UNUSED(y), widget_t* w)
{
    guint button = gtk_gesture_single_get_current_button (GTK_GESTURE_SINGLE (gesture));
    GdkModifierType state = gtk_event_controller_get_current_event_state(GTK_EVENT_CONTROLLER(gesture));

    gint ret;
    lua_State *L = common.L;
    luaH_object_push(L, w->ref);
    luaH_modifier_table_push(L, state);
    lua_pushinteger(L, button);

    if (n_press == 2) {
        ret = luaH_object_emit_signal(L, -3, "button-double-click", 2, 1);
    } else {
        ret = luaH_object_emit_signal(L, -3, "button-press", 2, 1);
    }

    lua_pop(L, ret + 1);
}

void
button_released_cb(GtkGestureClick *gesture, int UNUSED(n_press), double UNUSED(x), double UNUSED(y), widget_t *w)
{
    guint button = gtk_gesture_single_get_current_button (GTK_GESTURE_SINGLE (gesture));
    GdkModifierType state = gtk_event_controller_get_current_event_state(GTK_EVENT_CONTROLLER(gesture));
    lua_State *L = common.L;
    luaH_object_push(L, w->ref);
    luaH_modifier_table_push(L, state);
    lua_pushinteger(L, button);

    gint ret = luaH_object_emit_signal(L, -3, "button-release", 2, 1);
    lua_pop(L, ret + 1);
}

gboolean
scroll_cb(GtkEventControllerScroll *controller, double dx, double dy, widget_t *w)
{
    GdkModifierType state = gtk_event_controller_get_current_event_state(GTK_EVENT_CONTROLLER(controller));

    lua_State *L = common.L;
    luaH_object_push(L, w->ref);
    luaH_modifier_table_push(L, state);
    lua_pushnumber(L, dx);
    lua_pushnumber(L, dy);

    gboolean ret = luaH_object_emit_signal(L, -4, "scroll-input", 3, 1);
    lua_pop(L, ret + 1);
    return ret;
}

void
mouse_enter_cb(GtkEventControllerMotion *controller, double UNUSED(x), double UNUSED(y), widget_t *w)
{
    GdkModifierType state = gtk_event_controller_get_current_event_state(GTK_EVENT_CONTROLLER(controller));
    lua_State *L = common.L;
    luaH_object_push(L, w->ref);
    luaH_modifier_table_push(L, state);
    gint ret = luaH_object_emit_signal(L, -2, "mouse-enter", 1, 1);
    lua_pop(L, ret + 1);
}

void
mouse_leave_cb(GtkEventControllerMotion *controller, double UNUSED(x), double UNUSED(y), widget_t *w)
{
    GdkModifierType state = gtk_event_controller_get_current_event_state(GTK_EVENT_CONTROLLER(controller));
    lua_State *L = common.L;
    luaH_object_push(L, w->ref);
    luaH_modifier_table_push(L, state);
    gint ret = luaH_object_emit_signal(L, -2, "mouse-leave", 1, 1);
    lua_pop(L, ret + 1);
}

void
focus_enter_cb(GtkEventControllerFocus *UNUSED(controller), widget_t *w)
{
    lua_State *L = common.L;
    luaH_object_push(L, w->ref);
    gint ret = luaH_object_emit_signal(L, -1, "focus", 0, 1);
    lua_pop(L, ret + 1);
}

void
focus_leave_cb(GtkEventControllerFocus *UNUSED(controller), widget_t *w)
{
    lua_State *L = common.L;
    luaH_object_push(L, w->ref);
    gint ret = luaH_object_emit_signal(L, -1, "unfocus", 0, 1);
    lua_pop(L, ret + 1);
}


void
items_changed_cb(GListModel *model, guint position, guint removed, guint added, widget_t *w)
{
    if (added > 0) {
        GtkWidget *new_child = g_list_model_get_item(model, position);
        widget_t *child = GOBJECT_TO_LUAKIT_WIDGET(new_child);
        lua_State *L = common.L;
        luaH_object_push(L, w->ref);
        luaH_object_push(L, child->ref);
        luaH_object_emit_signal(L, -2, "add", 1, 0);
        lua_pop(L, 1);
        g_object_unref (new_child);
    }

    if (removed > 0) {
        lua_State *L = common.L;
        luaH_object_push(L, w->ref);
        luaH_object_push(L, NULL); // TODO: this has to be done differently as
                                   // the child is gone here already
        luaH_object_emit_signal(L, -2, "remove", 1, 0);
        lua_pop(L, 1);
    }
}

void
child_changed_cb(GObject *object, GParamSpec *UNUSED(pspec), widget_t *w)
{
    GtkWidget *widget = GTK_WIDGET(object);
    GtkWidget *new_child = NULL;

    if (GTK_IS_SCROLLED_WINDOW(widget))
        new_child = gtk_scrolled_window_get_child(GTK_SCROLLED_WINDOW(widget));
    else if (GTK_IS_WINDOW(widget))
        new_child = gtk_window_get_child(GTK_WINDOW(widget));
    else if (GTK_IS_OVERLAY(widget))
        new_child = gtk_overlay_get_child(GTK_OVERLAY(widget));
    else if (GTK_IS_FRAME(widget))
        new_child = gtk_frame_get_child(GTK_FRAME(widget));
    else
        new_child = gtk_widget_get_first_child(widget);

    if (new_child != NULL) {
        widget_t *child = GOBJECT_TO_LUAKIT_WIDGET(new_child);
        lua_State *L = common.L;
        luaH_object_push(L, w->ref);
        luaH_object_push(L, child->ref);
        luaH_object_emit_signal(L, -2, "add", 1, 0);
        lua_pop(L, 1);
    } else {
        lua_State *L = common.L;
        luaH_object_push(L, w->ref);
        luaH_object_push(L, NULL); // TODO: this has to be done differently as
                                   // the child is gone here already
        luaH_object_emit_signal(L, -2, "remove", 1, 0);
        lua_pop(L, 1);
    }
}

void
parent_changed_cb(GObject *object, GParamSpec *UNUSED(pspec), widget_t *w)
{
    lua_State *L = common.L;
    widget_t *parent = NULL;
    GtkWidget *widget = GTK_WIDGET(object);
    GtkWidget *new = gtk_widget_get_parent(widget);
    luaH_object_push(L, w->ref);
    if (new != NULL && (parent = GOBJECT_TO_LUAKIT_WIDGET(new)))
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

    /* Disconnect GTK widget signal handlers pointing to w */
    if (w->widget && G_IS_OBJECT(w->widget)) {
        g_signal_handlers_disconnect_by_data(w->widget, w);
    }

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
    GtkWidget *widget = NULL;

    if (GTK_IS_SCROLLED_WINDOW(w->widget))
        widget = gtk_scrolled_window_get_child(GTK_SCROLLED_WINDOW(w->widget));
    else if (GTK_IS_WINDOW(w->widget))
        widget = gtk_window_get_child(GTK_WINDOW(w->widget));
    else if (GTK_IS_OVERLAY(w->widget))
        widget = gtk_overlay_get_child(GTK_OVERLAY(w->widget));
    else
        widget = gtk_widget_get_first_child(GTK_WIDGET(w->widget));

    /* remove old child */
    if (widget) {
        g_object_ref(G_OBJECT(widget));
        if (GTK_IS_BOX(w->widget))
            gtk_box_remove(GTK_BOX(w->widget), GTK_WIDGET(widget));
        else if (GTK_IS_SCROLLED_WINDOW(w->widget))
            gtk_scrolled_window_set_child(GTK_SCROLLED_WINDOW(w->widget), NULL);
        else if (GTK_IS_WINDOW(w->widget))
            gtk_window_set_child(GTK_WINDOW(w->widget), NULL);
        else if (GTK_IS_OVERLAY(w->widget))
            gtk_overlay_set_child(GTK_OVERLAY(w->widget), NULL);
        else
            gtk_widget_unparent(GTK_WIDGET(widget));
    }

    /* add new child to container */
    if (child) {
        gtk_widget_set_hexpand(GTK_WIDGET(child->widget), TRUE);
        gtk_widget_set_vexpand(GTK_WIDGET(child->widget), TRUE);
        gtk_widget_set_halign(GTK_WIDGET(child->widget), GTK_ALIGN_FILL);
        gtk_widget_set_valign(GTK_WIDGET(child->widget), GTK_ALIGN_FILL);

        if (GTK_IS_BOX(w->widget))
            gtk_box_append(GTK_BOX(w->widget), GTK_WIDGET(child->widget));
        else if (GTK_IS_SCROLLED_WINDOW(w->widget))
            gtk_scrolled_window_set_child(GTK_SCROLLED_WINDOW(w->widget), GTK_WIDGET(child->widget));
        else if (GTK_IS_WINDOW(w->widget))
            gtk_window_set_child(GTK_WINDOW(w->widget), GTK_WIDGET(child->widget));
        else if (GTK_IS_OVERLAY(w->widget))
            gtk_overlay_set_child(GTK_OVERLAY(w->widget), GTK_WIDGET(child->widget));
        else
            gtk_widget_set_parent(GTK_WIDGET(child->widget), GTK_WIDGET(w->widget));
    }
    return 0;
}

/* get child method for gtk container widgets */
gint
luaH_widget_get_child(lua_State *L, widget_t *w)
{
    GtkWidget *widget = NULL;

    if (GTK_IS_SCROLLED_WINDOW(w->widget))
        widget = gtk_scrolled_window_get_child(GTK_SCROLLED_WINDOW(w->widget));
    else if (GTK_IS_WINDOW(w->widget))
        widget = gtk_window_get_child(GTK_WINDOW(w->widget));
    else if (GTK_IS_OVERLAY(w->widget))
        widget = gtk_overlay_get_child(GTK_OVERLAY(w->widget));
    else
        widget = gtk_widget_get_first_child(GTK_WIDGET(w->widget));

    if (!widget)
        return 0;

    widget_t *child = GOBJECT_TO_LUAKIT_WIDGET(widget);
    if (!child)
        return 0;
    luaH_object_push(L, child->ref);
    return 1;
}

gint
luaH_widget_remove(lua_State *L)
{
    widget_t *w = luaH_checkwidget(L, 1);
    widget_t *child = luaH_checkwidget(L, 2);

    if (child) {
        g_object_ref(G_OBJECT(child->widget));
        if (GTK_IS_BOX(w->widget))
            gtk_box_remove(GTK_BOX(w->widget), GTK_WIDGET(child->widget));
        else if (GTK_IS_NOTEBOOK(w->widget)) {
            gint page_num = gtk_notebook_page_num(GTK_NOTEBOOK(w->widget), child->widget);
            if (page_num >= 0)
                gtk_notebook_remove_page(GTK_NOTEBOOK(w->widget), page_num);
        } else if (GTK_IS_STACK(w->widget))
            gtk_stack_remove(GTK_STACK(w->widget), child->widget);
        else if (GTK_IS_SCROLLED_WINDOW(w->widget))
            gtk_scrolled_window_set_child(GTK_SCROLLED_WINDOW(w->widget), NULL);
        else if (GTK_IS_WINDOW(w->widget))
            gtk_window_set_child(GTK_WINDOW(w->widget), NULL);
        else if (GTK_IS_OVERLAY(w->widget))
            gtk_overlay_set_child(GTK_OVERLAY(w->widget), NULL);
        else
            gtk_widget_unparent(GTK_WIDGET(child->widget));
    }

    return 0;
}

gint
luaH_widget_get_children(lua_State *L, widget_t *w)
{
    lua_newtable(L);
    gint i = 1;

    if (GTK_IS_NOTEBOOK(w->widget)) {
        gint n = gtk_notebook_get_n_pages(GTK_NOTEBOOK(w->widget));
        for (gint idx = 0; idx < n; idx++) {
            GtkWidget *child = gtk_notebook_get_nth_page(GTK_NOTEBOOK(w->widget), idx);
            if (child) {
                widget_t *child_w = GOBJECT_TO_LUAKIT_WIDGET(child);
                if (child_w) {
                    luaH_object_push(L, child_w->ref);
                    lua_rawseti(L, -2, i++);
                }
            }
        }
    } else {
        for (GtkWidget *child = gtk_widget_get_first_child(GTK_WIDGET(w->widget));
             child != NULL;
             child = gtk_widget_get_next_sibling(child)) {

            widget_t *child_w = GOBJECT_TO_LUAKIT_WIDGET(child);
            if (child_w) {
                /* push table of the containers children onto the stack */
                luaH_object_push(L, child_w->ref);
                lua_rawseti(L, -2, i++);
            }
        }
    }

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

    GtkLayoutManager *layout_mgr = gtk_widget_get_layout_manager(parent);

    if (layout_mgr != NULL) {
        GtkLayoutChild *old_layout_child = gtk_layout_manager_get_layout_child(layout_mgr, GTK_WIDGET(och->widget));
        GObjectClass *layout_class = G_OBJECT_GET_CLASS(old_layout_child);

        // 3. Introspect all exposed positioning properties (e.g., column, row, row-span)
        guint num_props;
        GParamSpec **props = g_object_class_list_properties(layout_class, &num_props);

        GValue *values = g_new0(GValue, num_props);
        for (guint i = 0; i < num_props; i++)
        {
            g_value_init(&values[i], G_PARAM_SPEC_VALUE_TYPE(props[i]));
            g_object_get_property(G_OBJECT(old_layout_child), props[i]->name, &values[i]);
        }

        g_object_ref(G_OBJECT(och->widget));
        gtk_widget_unparent(GTK_WIDGET(och->widget));


        gtk_widget_set_hexpand(GTK_WIDGET(nch->widget), TRUE);
        gtk_widget_set_vexpand(GTK_WIDGET(nch->widget), TRUE);
        gtk_widget_set_halign(GTK_WIDGET(nch->widget), GTK_ALIGN_FILL);
        gtk_widget_set_valign(GTK_WIDGET(nch->widget), GTK_ALIGN_FILL);

        if (GTK_IS_BOX(parent)) {
            gtk_box_append(GTK_BOX(parent), GTK_WIDGET(nch->widget));
        } else if (GTK_IS_OVERLAY(parent)) {
            gtk_overlay_set_child(GTK_OVERLAY(parent), GTK_WIDGET(nch->widget));
        } else if (GTK_IS_WINDOW(parent)) {
            gtk_window_set_child(GTK_WINDOW(parent), GTK_WIDGET(nch->widget));
        } else if (GTK_IS_SCROLLED_WINDOW(parent)) {
            gtk_scrolled_window_set_child(GTK_SCROLLED_WINDOW(parent), GTK_WIDGET(nch->widget));
        } else {
            gtk_widget_set_parent(GTK_WIDGET(nch->widget), parent);
        }

        GtkLayoutChild *new_layout_child = gtk_layout_manager_get_layout_child(layout_mgr, GTK_WIDGET(nch->widget));
        for (guint i = 0; i < num_props; i++)
        {
            if (new_layout_child) {
                g_object_set_property(G_OBJECT(new_layout_child), props[i]->name, &values[i]);
            }
            g_value_unset(&values[i]);
        }

        g_free(props);
        g_free(values);
    } else {
        gtk_widget_set_hexpand(GTK_WIDGET(nch->widget), TRUE);
        gtk_widget_set_vexpand(GTK_WIDGET(nch->widget), TRUE);
        gtk_widget_set_halign(GTK_WIDGET(nch->widget), GTK_ALIGN_FILL);
        gtk_widget_set_valign(GTK_WIDGET(nch->widget), GTK_ALIGN_FILL);

        // Fallback for single-child containers (e.g., GtkWindow, GtkButton, GtkFrame, GtkOverlay)
        if (GTK_IS_WINDOW(parent)) {
            gtk_window_set_child(GTK_WINDOW(parent), GTK_WIDGET(nch->widget));
        } else if (GTK_IS_OVERLAY(parent)) {
            gtk_overlay_set_child(GTK_OVERLAY(parent), GTK_WIDGET(nch->widget));
        } else if (GTK_IS_BUTTON(parent)) {
            gtk_button_set_child(GTK_BUTTON(parent), GTK_WIDGET(nch->widget));
        } else {
            gtk_widget_set_parent(GTK_WIDGET(nch->widget), parent);
        }
    }
    return 0;
}

gint
luaH_widget_show(lua_State *L)
{
    widget_t *w = luaH_checkwidget(L, 1);
    if (GTK_IS_WINDOW(w->widget))
        gtk_window_present(GTK_WINDOW(w->widget));
    else
        gtk_widget_set_visible(w->widget, TRUE);
    return 0;
}

gint
luaH_widget_hide(lua_State *L)
{
    widget_t *w = luaH_checkwidget(L, 1);
    gtk_widget_set_visible(w->widget, FALSE);
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
        MODKEY("mod1", ALT);
        MODKEY("mod2", META);
        MODKEY("mod4", SUPER);
        MODKEY("mod5", HYPER);

#undef MODKEY

        lua_pop(L, 1);
    }

    GtkEventControllerKey *key_controller = NULL;
    GListModel *controllers = gtk_widget_observe_controllers(w->widget);

    if (controllers) {
        guint n_items = g_list_model_get_n_items(controllers);
        for (guint i = 0; i < n_items; i++) {
            gpointer item = g_list_model_get_item(controllers, i);
            if (GTK_IS_EVENT_CONTROLLER_KEY(item)) {
                key_controller = GTK_EVENT_CONTROLLER_KEY(item);
                break;
            }
            g_object_unref(item);
        }
    }

    GdkKeymapKey *keys = NULL;
    gint n_keys;
    guint hardware_keycode = 0;
    GdkDisplay *display = gtk_widget_get_display(w->widget);
    GdkSeat *seat = gdk_display_get_default_seat(display);
    GdkDevice *kbd = gdk_seat_get_keyboard(seat);

    if (gdk_device_get_caps_lock_state(kbd) || TRUE) { // Ensure device handles
        if (gdk_display_map_keyval(display, keyval, &keys, &n_keys)) {
            if (n_keys > 0) {
                hardware_keycode = keys[0].keycode;
            }
            g_free(keys);
        }
    }

    gboolean ret;
    debug("sending key '%s%s' to widget %p", state_string->str, key_name, w->widget);
    g_signal_emit_by_name(key_controller,
        is_release ? "key-released" : "key-pressed",
        keyval,        // The key value (e.g., GDK_KEY_Return)
        hardware_keycode,       // Physical hardware keycode code
        state,     // Active modifiers
        &ret);     // Output boolean tracking pointer

    g_string_free(state_string, TRUE);
    return 0;
}

gint
luaH_widget_set_visible(lua_State *L, widget_t *w)
{
    gboolean visible = luaH_checkboolean(L, 3);
    gtk_widget_set_visible(w->widget, visible);
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
             valign = gtk_widget_get_valign(GTK_WIDGET(w->widget));
    if (valign == GTK_ALIGN_BASELINE_FILL) {
        lua_createtable(L, 0, 2);
        /* set align.h */
        lua_pushliteral(L, "h");
        lua_pushnumber(L, halign);
        lua_rawset(L, -3);
        /* set align.v */
        lua_pushliteral(L, "v");
        lua_pushnumber(L, valign);
        lua_rawset(L, -3);
    }
    return 1;
}

gint
luaH_widget_set_align(lua_State *L, widget_t *w)
{
    luaH_checktable(L, 3);
    GtkAlign halign = gtk_widget_get_halign(GTK_WIDGET(w->widget)),
             valign = gtk_widget_get_valign(GTK_WIDGET(w->widget));
    if (luaH_rawfield(L, 3, "h"))
        switch (l_tokenize(lua_tostring(L, -1))) {
            case L_TK_FILL:     halign = GTK_ALIGN_FILL;     break;
            case L_TK_START:    halign = GTK_ALIGN_START;    break;
            case L_TK_END:      halign = GTK_ALIGN_END;      break;
            case L_TK_CENTER:   halign = GTK_ALIGN_CENTER;   break;
            case L_TK_BASELINE: halign = GTK_ALIGN_BASELINE_FILL; break;
            default:
                return luaL_error(L, "Bad alignment value (expected fill, start, end, center, or baseline)");
        }
    if (luaH_rawfield(L, 3, "v"))
        switch (l_tokenize(lua_tostring(L, -1))) {
            case L_TK_FILL:     valign = GTK_ALIGN_FILL;     break;
            case L_TK_START:    valign = GTK_ALIGN_START;    break;
            case L_TK_END:      valign = GTK_ALIGN_END;      break;
            case L_TK_CENTER:   valign = GTK_ALIGN_CENTER;   break;
            case L_TK_BASELINE: valign = GTK_ALIGN_BASELINE_FILL; break;
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
    GtkWidget *widget = GTK_WIDGET(w->widget);
    if (widget != NULL && GTK_IS_WIDGET(widget))
    {
        GtkWidget *parent = gtk_widget_get_parent(widget);
        if (parent == NULL)
            return 0;

        widget_t *parent_w = GOBJECT_TO_LUAKIT_WIDGET(parent);
        if (parent_w) {
            luaH_object_push(L, parent_w->ref);
            return 1;
        }
    }

    return 0;
}

gint
luaH_widget_get_ancestor(lua_State *L)
{
    widget_t *w = luaH_checkwidget(L, 1);
    GtkWidget *widget = GTK_WIDGET(w->widget);
    if (widget != NULL && GTK_IS_WIDGET(widget))
    {
        const char *prop = luaL_checkstring(L, 2);
        //TODO: rewrite to more generic approach, that works for all known types
        if (g_str_equal(prop, "window"))
        {
            GtkWidget *parent = gtk_widget_get_ancestor(widget, GTK_TYPE_WINDOW);
            if (parent == NULL)
                return 0;

            widget_t *parent_w = GOBJECT_TO_LUAKIT_WIDGET(parent);
            if (parent_w) {
                luaH_object_push(L, parent_w->ref);
                return 1;
            }
        }
    }

    return 0;
}

gint
luaH_widget_get_focused(lua_State *L, widget_t *w)
{
    gboolean focused = w->info->tok == L_TK_WINDOW ?
        gtk_window_is_active(GTK_WINDOW(w->widget)) :
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
    lua_pushnumber(L, gtk_widget_get_width(w->widget));
    return 1;
}

gint
luaH_widget_get_height(lua_State *L, widget_t *w)
{
    lua_pushnumber(L, gtk_widget_get_height(w->widget));
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
            gtk_widget_grab_focus(w->widget);
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
    if (w->widget) {
        if (GTK_IS_WINDOW(w->widget)) {
            gtk_window_destroy(GTK_WINDOW(w->widget));
            return 0;
        }

        GtkWidget *widget = w->widget;
        g_object_ref(G_OBJECT(widget));

        /* Emit destroy signal, run destructor, etc. */
        destroy_cb(widget, w);

        if (gtk_widget_get_parent(widget)) {
            gtk_widget_unparent(widget);
        } else {
            g_object_ref_sink(G_OBJECT(widget));
            g_object_unref(G_OBJECT(widget));
        }
        g_object_unref(G_OBJECT(widget));
    }
    return 0;
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
