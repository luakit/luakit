/*
 * widgets/entry.c - gtk entry widget wrapper
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

#include "luah.h"
#include "widgets/common.h"

static gint
luaH_entry_append(lua_State *L)
{
    size_t len;
    widget_t *w = luaH_checkudata(L, 1, &widget_class);
    const gchar *text = luaL_checklstring(L, 2, &len);
    gint pos = -1;

    gtk_editable_insert_text(GTK_EDITABLE(w->widget),
        text, g_utf8_strlen(text, len), &pos);

    return pos + 1;
}

static gint
luaH_entry_insert(lua_State *L)
{
    size_t len;
    widget_t *w = luaH_checkudata(L, 1, &widget_class);
    gint pos = luaL_checknumber(L, 2);
    /* lua table indexes start at 1 */
    if (pos > 0) pos--;
    const gchar *text = luaL_checklstring(L, 3, &len);

    gtk_editable_insert_text(GTK_EDITABLE(w->widget),
        text, g_utf8_strlen(text, len), &pos);

    return pos + 1;
}

static gint
luaH_entry_set_position(lua_State *L)
{
    widget_t *w = luaH_checkudata(L, 1, &widget_class);
    gint pos = luaL_checknumber(L, 2);
    /* lua table indexes start at 1 */
    if (pos > 0) pos--;

    gtk_editable_set_position(GTK_EDITABLE(w->widget), pos);
    lua_pushnumber(L, gtk_editable_get_position(GTK_EDITABLE(w->widget)));
    return 1;
}

static gint
luaH_entry_get_position(lua_State *L)
{
    widget_t *w = luaH_checkudata(L, 1, &widget_class);
    lua_pushnumber(L, gtk_editable_get_position(GTK_EDITABLE(w->widget)));
    return 1;
}

static gint
luaH_entry_index(lua_State *L, luakit_token_t token)
{
    widget_t *w = luaH_checkudata(L, 1, &widget_class);

    switch(token)
    {
      case L_TK_TEXT:
        lua_pushstring(L, gtk_entry_get_text(GTK_ENTRY(w->widget)));
        return 1;

      case L_TK_FG:
        lua_pushstring(L, g_object_get_data(G_OBJECT(w->widget), "fg"));
        return 1;

      case L_TK_BG:
        lua_pushstring(L, g_object_get_data(G_OBJECT(w->widget), "bg"));
        return 1;

      case L_TK_APPEND:
        lua_pushcfunction(L, luaH_entry_append);
        return 1;

      case L_TK_INSERT:
        lua_pushcfunction(L, luaH_entry_insert);
        return 1;

      case L_TK_GET_POSITION:
        lua_pushcfunction(L, luaH_entry_get_position);
        return 1;

      case L_TK_SET_POSITION:
        lua_pushcfunction(L, luaH_entry_set_position);
        return 1;

      case L_TK_SHOW_FRAME:
        lua_pushboolean(L, gtk_entry_get_has_frame(GTK_ENTRY(w->widget)));
        return 1;

      case L_TK_FONT:
        lua_pushstring(L, g_object_get_data(G_OBJECT(w->widget), "font"));
        return 1;

      case L_TK_SHOW:
        lua_pushcfunction(L, luaH_widget_show);
        return 1;

      case L_TK_HIDE:
        lua_pushcfunction(L, luaH_widget_hide);
        return 1;

      case L_TK_FOCUS:
        lua_pushcfunction(L, luaH_widget_focus);
        return 1;

      default:
        warn("unknown property: %s", luaL_checkstring(L, 2));
        break;
    }
    return 0;
}

static gint
luaH_entry_newindex(lua_State *L, luakit_token_t token)
{
    size_t len;
    widget_t *w = luaH_checkudata(L, 1, &widget_class);
    const gchar *tmp;
    GdkColor c;
    PangoFontDescription *font;

    switch(token)
    {
      case L_TK_TEXT:
        gtk_entry_set_text(GTK_ENTRY(w->widget),
            luaL_checklstring(L, 3, &len));
        break;

      case L_TK_FG:
      case L_TK_BG:
        tmp = luaL_checklstring(L, 3, &len);
        if (!gdk_color_parse(tmp, &c)) {
            warn("invalid color: %s", tmp);
            return 0;
        }

        if (token == L_TK_FG) {
            gtk_widget_modify_text(GTK_WIDGET(w->widget), GTK_STATE_NORMAL, &c);
            g_object_set_data_full(G_OBJECT(w->widget), "fg", g_strdup(tmp), g_free);
        } else {
            gtk_widget_modify_base(GTK_WIDGET(w->widget), GTK_STATE_NORMAL, &c);
            g_object_set_data_full(G_OBJECT(w->widget), "bg", g_strdup(tmp), g_free);
        }
        break;

      case L_TK_SHOW_FRAME:
        gtk_entry_set_has_frame(GTK_ENTRY(w->widget), luaH_checkboolean(L, 3));
        break;

      case L_TK_FONT:
        tmp = luaL_checklstring(L, 3, &len);
        font = pango_font_description_from_string(tmp);
        gtk_widget_modify_font(GTK_WIDGET(w->widget), font);
        g_object_set_data_full(G_OBJECT(w->widget), "font", g_strdup(tmp), g_free);
        break;

      default:
        warn("unknown property: %s", luaL_checkstring(L, 2));
        return 0;
    }

    return luaH_object_emit_property_signal(L, 1);
}

static void
activate_cb(GtkEntry *e, widget_t *w)
{
    (void) e;
    lua_State *L = globalconf.L;
    luaH_object_push(L, w->ref);
    luaH_object_emit_signal(L, -1, "activate", 0, 0);
    lua_pop(L, 1);
}

static void
changed_cb(GtkEditable *e, widget_t *w)
{
    (void) e;
    lua_State *L = globalconf.L;
    luaH_object_push(L, w->ref);
    luaH_object_emit_signal(L, -1, "changed", 0, 0);
    lua_pop(L, 1);
}

static void
entry_destructor(widget_t *w)
{
    gtk_widget_destroy(w->widget);
}

widget_t *
widget_entry(widget_t *w)
{
    w->index = luaH_entry_index;
    w->newindex = luaH_entry_newindex;
    w->destructor = entry_destructor;

    /* create gtk label widget as main widget */
    w->widget = gtk_entry_new();
    g_object_set_data(G_OBJECT(w->widget), "widget", (gpointer) w);

    /* setup default settings */
    gtk_entry_set_inner_border(GTK_ENTRY(w->widget), NULL);

    g_object_connect((GObject*)w->widget,
      "signal::activate",          (GCallback)activate_cb,    w,
      "signal::changed",           (GCallback)changed_cb,     w,
      "signal::focus-in-event",    (GCallback)focus_cb,       w,
      "signal::focus-out-event",   (GCallback)focus_cb,       w,
      "signal::key-press-event",   (GCallback)key_press_cb,   w,
      "signal::parent-set",        (GCallback)parent_set_cb,  w,
      NULL);

    gtk_widget_show(w->widget);
    return w;
}

// vim: ft=c:et:sw=4:ts=8:sts=4:enc=utf-8:tw=80
