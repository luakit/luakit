/*
 * widgets/common.h - common widget functions or callbacks
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

#ifndef LUAKIT_WIDGETS_COMMON_H
#define LUAKIT_WIDGETS_COMMON_H

#include "clib/widget.h"

#define LUAKIT_WIDGET_INDEX_COMMON(widget)            \
    case L_TK_PARENT:                                \
      return luaH_widget_get_parent(L, widget);      \
    case L_TK_FOCUSED:                                \
      return luaH_widget_get_focused(L, widget);      \
    case L_TK_VISIBLE:                                \
      return luaH_widget_get_visible(L, widget);      \
    case L_TK_TOOLTIP:                                \
      return luaH_widget_get_tooltip(L, widget);      \
    case L_TK_WIDTH:                                  \
      return luaH_widget_get_width(L, widget);        \
    case L_TK_HEIGHT:                                 \
      return luaH_widget_get_height(L, widget);       \
    case L_TK_MIN_SIZE:                               \
      return luaH_widget_get_min_size(L, widget);     \
    case L_TK_ALIGN:                                  \
      return luaH_widget_get_align(L, widget);        \
    case L_TK_CHILDREN:                               \
      return luaH_widget_get_children(L, widget);     \
    case L_TK_SHOW:                                   \
      lua_pushcfunction(L, luaH_widget_show);         \
      return 1;                                       \
    case L_TK_HIDE:                                   \
      lua_pushcfunction(L, luaH_widget_hide);         \
      return 1;                                       \
    case L_TK_FOCUS:                                  \
      lua_pushcfunction(L, luaH_widget_focus);        \
      return 1;                                       \
    case L_TK_REPLACE:                                \
      lua_pushcfunction(L, luaH_widget_replace);      \
      return 1;                                       \
    case L_TK_SEND_KEY:                               \
      lua_pushcfunction(L, luaH_widget_send_key);     \
      return 1;                                       \
    case L_TK_REMOVE:                                 \
      lua_pushcfunction(L, luaH_widget_remove);       \
      return 1;                                       \

#define LUAKIT_WIDGET_NEWINDEX_COMMON(widget)         \
    case L_TK_VISIBLE:                                \
      luaH_widget_set_visible(L, widget);             \
      break;                                          \
    case L_TK_TOOLTIP:                                \
      luaH_widget_set_tooltip(L, widget);             \
      break;                                          \
    case L_TK_MIN_SIZE:                               \
      luaH_widget_set_min_size(L, widget);            \
      break;                                          \
    case L_TK_ALIGN:                                  \
      luaH_widget_set_align(L, widget);               \
      break;                                          \

#define LUAKIT_WIDGET_CHILD_INDEX_COMMON(widget)        \
    case L_TK_CHILD:                                  \
      return luaH_widget_get_child(L, widget);

#define LUAKIT_WIDGET_CHILD_NEWINDEX_COMMON(widget)     \
    case L_TK_CHILD:                                  \
      luaH_widget_set_child(L, widget);               \
      break;

#define LUAKIT_WIDGET_SIGNAL_COMMON(w)                       \
    "signal::destroy",         G_CALLBACK(destroy_cb),    w, \
    "signal::size-allocate",   G_CALLBACK(resize_cb),     w, \
    "signal::notify::parent",      G_CALLBACK(parent_changed_cb), w,

#define LUAKIT_WIDGET_SIGNAL_FOCUS(w)                 \
    "signal::enter",  G_CALLBACK(focus_enter_cb),          w, \
    "signal::leave", G_CALLBACK(focus_leave_cb),           w,

#define LUAKIT_WIDGET_SIGNAL_GESTURES(w)                       \
    "signal::pressed",   G_CALLBACK(button_press_cb),     w, \
    "signal::released", G_CALLBACK(button_released_cb),     w,

#define LUAKIT_WIDGET_SIGNAL_SCROLL(w)                       \
    "signal::scroll",         G_CALLBACK(scroll_cb),     w,

#define LUAKIT_WIDGET_SIGNAL_MOTION(w)                       \
    "signal::enter",   G_CALLBACK(mouse_enter_cb),      w, \
    "signal::leave",   G_CALLBACK(mouse_leave_cb),      w,


#define LUAKIT_EVENT_CONTROLLER_KEY(win, w) \
    GtkEventController *key_controller = gtk_event_controller_key_new(); \
    g_signal_connect(key_controller, \
        "key-pressed", G_CALLBACK(key_press_cb), w \
    );                                             \
    gtk_widget_add_controller(win, key_controller);

gboolean scroll_cb(GtkEventControllerScroll*, double, double, widget_t*);

void mouse_enter_cb(GtkEventControllerMotion*, double, double, widget_t*);
void mouse_leave_cb(GtkEventControllerMotion*, double, double, widget_t*);

void focus_enter_cb(GtkEventControllerFocus*, widget_t*);
void focus_leave_cb(GtkEventControllerFocus*, widget_t*);

gboolean key_press_cb(GtkEventControllerKey*, guint, guint, GdkModifierType, widget_t*);

gboolean true_cb();

void button_pressed_cb(GtkGestureClick*, int, double, double, widget_t*);
void button_released_cb(GtkGestureClick*, int, double, double, widget_t*);

void child_changed_cb(GObject*, GParamSpec*, widget_t*);
void items_changed_cb(GListModel *, guint, guint, guint, widget_t*);

void parent_changed_cb(GObject*, GParamSpec*, widget_t*);
void resize_cb(GtkWidget*, GdkRectangle *, widget_t *);
void destroy_cb(GtkWidget* UNUSED(win), widget_t *w);
void widget_destructor(widget_t*);

gint luaH_widget_destroy(lua_State*);
gint luaH_widget_focus(lua_State*);
gint luaH_widget_get_child(lua_State*, widget_t*);
gint luaH_widget_get_children(lua_State*, widget_t*);
gint luaH_widget_hide(lua_State*);
gint luaH_widget_remove(lua_State*);
gint luaH_widget_set_child(lua_State*, widget_t*);
gint luaH_widget_show(lua_State*);
gint luaH_widget_replace(lua_State*);
gint luaH_widget_send_key(lua_State *);
gint luaH_widget_get_parent(lua_State *L, widget_t *w);
gint luaH_widget_get_focused(lua_State *L, widget_t*);
gint luaH_widget_get_visible(lua_State *L, widget_t*);
gint luaH_widget_get_width(lua_State *L, widget_t*);
gint luaH_widget_get_height(lua_State *L, widget_t*);
gint luaH_widget_set_visible(lua_State *L, widget_t*);
gint luaH_widget_set_tooltip(lua_State *L, widget_t *w);
gint luaH_widget_get_tooltip(lua_State *L, widget_t *w);
gint luaH_widget_set_min_size(lua_State *L, widget_t *w);
gint luaH_widget_get_min_size(lua_State *L, widget_t *w);
gint luaH_widget_set_align(lua_State *L, widget_t *w);
gint luaH_widget_get_align(lua_State *L, widget_t *w);

#endif

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
