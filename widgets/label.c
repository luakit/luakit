/*
 * widgets/label.c - gtk text area widget
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
luaH_label_set_alignment(lua_State *L)
{
    widget_t *w = luaH_checkudata(L, 1, &widget_class);
    gfloat xalign = luaL_checknumber(L, 2);
    gfloat yalign = luaL_checknumber(L, 3);
    gtk_misc_set_alignment(GTK_MISC(w->widget), xalign, yalign);
    return 0;
}

static gint
luaH_label_get_alignment(lua_State *L)
{
    widget_t *w = luaH_checkudata(L, 1, &widget_class);
    gfloat xalign, yalign;
    gtk_misc_get_alignment(GTK_MISC(w->widget), &xalign, &yalign);
    lua_pushnumber(L, xalign);
    lua_pushnumber(L, yalign);
    return 2;
}

static gint
luaH_label_set_padding(lua_State *L)
{
    widget_t *w = luaH_checkudata(L, 1, &widget_class);
    gint xpad = luaL_checknumber(L, 2);
    gint ypad = luaL_checknumber(L, 3);
    gtk_misc_set_padding(GTK_MISC(w->widget), xpad, ypad);
    return 0;
}

static gint
luaH_label_get_padding(lua_State *L)
{
    widget_t *w = luaH_checkudata(L, 1, &widget_class);
    gint xpad, ypad;
    gtk_misc_get_padding(GTK_MISC(w->widget), &xpad, &ypad);
    lua_pushnumber(L, xpad);
    lua_pushnumber(L, ypad);
    return 2;
}

static gint
luaH_label_index(lua_State *L, luakit_token_t token)
{
    widget_t *w = luaH_checkudata(L, 1, &widget_class);

    switch(token)
    {
      case L_TK_DESTROY:
        lua_pushcfunction(L, luaH_widget_destroy);
        return 1;

      case L_TK_TEXT:
        lua_pushstring(L, gtk_label_get_label(GTK_LABEL(w->widget)));
        return 1;

      case L_TK_SET_ALIGNMENT:
        lua_pushcfunction(L, luaH_label_set_alignment);
        return 1;

      case L_TK_GET_ALIGNMENT:
        lua_pushcfunction(L, luaH_label_get_alignment);
        return 1;

      case L_TK_SET_PADDING:
        lua_pushcfunction(L, luaH_label_set_padding);
        return 1;

      case L_TK_GET_PADDING:
        lua_pushcfunction(L, luaH_label_get_padding);
        return 1;

      case L_TK_FG:
        lua_pushstring(L, g_object_get_data(G_OBJECT(w->widget), "fg"));
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

      case L_TK_SELECTABLE:
        lua_pushboolean(L, gtk_label_get_selectable(GTK_LABEL(w->widget)));
        return 1;

      default:
        warn("unknown property: %s", luaL_checkstring(L, 2));
        break;
    }
    return 0;
}

static gint
luaH_label_newindex(lua_State *L, luakit_token_t token)
{
    size_t len;
    widget_t *w = luaH_checkudata(L, 1, &widget_class);
    const gchar *tmp;
    GdkColor c;
    PangoFontDescription *font;

    switch(token)
    {
      case L_TK_TEXT:
        gtk_label_set_markup(GTK_LABEL(w->widget),
            luaL_checklstring(L, 3, &len));
        break;

      case L_TK_FG:
        tmp = luaL_checklstring(L, 3, &len);
        if (!gdk_color_parse(tmp, &c)) {
            warn("invalid color: %s", tmp);
            return 0;
        }

        gtk_widget_modify_fg(GTK_WIDGET(w->widget), GTK_STATE_NORMAL, &c);
        g_object_set_data_full(G_OBJECT(w->widget), "fg", g_strdup(tmp), g_free);
        break;

      case L_TK_FONT:
        tmp = luaL_checklstring(L, 3, &len);
        font = pango_font_description_from_string(tmp);
        gtk_widget_modify_font(GTK_WIDGET(w->widget), font);
        g_object_set_data_full(G_OBJECT(w->widget), "font", g_strdup(tmp), g_free);
        break;

      case L_TK_SELECTABLE:
        gtk_label_set_selectable(GTK_LABEL(w->widget), luaH_checkboolean(L, 3));
        break;

      default:
        warn("unknown property: %s", luaL_checkstring(L, 2));
        return 0;
    }

    return luaH_object_emit_property_signal(L, 1);
}

static void
label_destructor(widget_t *w)
{
    gtk_widget_destroy(w->widget);
}

widget_t *
widget_label(widget_t *w)
{
    w->index = luaH_label_index;
    w->newindex = luaH_label_newindex;
    w->destructor = label_destructor;

    /* create gtk label widget as main widget */
    w->widget = gtk_label_new(NULL);
    g_object_set_data(G_OBJECT(w->widget), "widget", (gpointer) w);

    /* setup default settings */
    gtk_label_set_selectable(GTK_LABEL(w->widget), FALSE);
    gtk_label_set_use_markup(GTK_LABEL(w->widget), TRUE);
    gtk_misc_set_alignment(GTK_MISC(w->widget), 0, 0);
    gtk_misc_set_padding(GTK_MISC(w->widget), 2, 2);

    g_object_connect((GObject*)w->widget,
      "signal::focus-in-event",    (GCallback)focus_cb,       w,
      "signal::focus-out-event",   (GCallback)focus_cb,       w,
      "signal::key-press-event",   (GCallback)key_press_cb,   w,
      "signal::parent-set",        (GCallback)parent_set_cb,  w,
      NULL);

    gtk_widget_show(w->widget);
    return w;
}

// vim: ft=c:et:sw=4:ts=8:sts=4:enc=utf-8:tw=80
