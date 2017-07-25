/*
 * widgets/entry.c - gtk entry widget wrapper
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

#include "luah.h"
#include "widgets/common.h"

static gint
luaH_entry_insert(lua_State *L)
{
    widget_t *w = luaH_checkwidget(L, 1);

    /* get insert position (or append text) */
    gint pos = -1, idx = 2;
    if (lua_gettop(L) > 2) {
        pos = luaL_checknumber(L, idx++);
        if (pos > 0) pos--; /* correct lua index */
    }

    gtk_editable_insert_text(GTK_EDITABLE(w->widget),
        luaL_checkstring(L, idx), -1, &pos);
    return 0;
}

static gint
luaH_entry_select_region(lua_State* L)
{
    widget_t *w = luaH_checkwidget(L, 1);
    gint startpos = luaL_checknumber(L, 2);
    gint endpos = -1;
    if(lua_gettop(L) > 2)
        endpos = luaL_checknumber(L, 3);

    gtk_editable_select_region(GTK_EDITABLE(w->widget), startpos, endpos);
    return 0;
}

static gint
luaH_entry_index(lua_State *L, widget_t *w, luakit_token_t token)
{
    switch(token) {
      LUAKIT_WIDGET_INDEX_COMMON(w)

      /* push class methods */
      PF_CASE(INSERT,           luaH_entry_insert)
      PF_CASE(SELECT_REGION,    luaH_entry_select_region)
      /* push integer properties */
      PI_CASE(POSITION,         gtk_editable_get_position(GTK_EDITABLE(w->widget)))
      /* push string properties */
      PS_CASE(TEXT,         gtk_entry_get_text(GTK_ENTRY(w->widget)))
      PS_CASE(FG,           g_object_get_data(G_OBJECT(w->widget), "fg"))
      PS_CASE(BG,           g_object_get_data(G_OBJECT(w->widget), "bg"))
      PS_CASE(FONT,         g_object_get_data(G_OBJECT(w->widget), "font"))
      /* push boolean properties */
      PB_CASE(SHOW_FRAME,   gtk_entry_get_has_frame(GTK_ENTRY(w->widget)))

      default:
        break;
    }
    return 0;
}

static gint
luaH_entry_newindex(lua_State *L, widget_t *w, luakit_token_t token)
{
    size_t len;
    const gchar *tmp;
    GdkRGBA c;
#if !GTK_CHECK_VERSION(3,16,0)
    PangoFontDescription *font;
#endif

    switch(token) {
      LUAKIT_WIDGET_NEWINDEX_COMMON(w)

      case L_TK_TEXT:
        gtk_entry_set_text(GTK_ENTRY(w->widget),
            luaL_checklstring(L, 3, &len));
        break;

      case L_TK_FG:
      case L_TK_BG:
        tmp = luaL_checklstring(L, 3, &len);
        if (!gdk_rgba_parse(&c, tmp))
            luaL_argerror(L, 3, "unable to parse color");
        if (token == L_TK_FG) {
#if GTK_CHECK_VERSION(3,16,0)
            widget_set_css_properties(w, "color", tmp, NULL);
#else
            gtk_widget_override_color(GTK_WIDGET(w->widget), GTK_STATE_FLAG_NORMAL, &c);
#endif
            g_object_set_data_full(G_OBJECT(w->widget), "fg", g_strdup(tmp), g_free);
        } else {
#if GTK_CHECK_VERSION(3,16,0)
            widget_set_css_properties(w, "background-color", tmp, NULL);
#else
            gtk_widget_override_background_color(GTK_WIDGET(w->widget), GTK_STATE_FLAG_NORMAL, &c);
#endif
            g_object_set_data_full(G_OBJECT(w->widget), "bg", g_strdup(tmp), g_free);
        }
        break;

      case L_TK_SHOW_FRAME:
        gtk_entry_set_has_frame(GTK_ENTRY(w->widget), luaH_checkboolean(L, 3));
        break;

      case L_TK_POSITION:
        gtk_editable_set_position(GTK_EDITABLE(w->widget), luaL_checknumber(L, 3));
        break;

      case L_TK_FONT:
        tmp = luaL_checklstring(L, 3, &len);
#if GTK_CHECK_VERSION(3,16,0)
        widget_set_css_properties(w, "font", tmp, NULL);
#else
        font = pango_font_description_from_string(tmp);
        gtk_widget_override_font(GTK_WIDGET(w->widget), font);
#endif
        g_object_set_data_full(G_OBJECT(w->widget), "font", g_strdup(tmp), g_free);
        break;

      default:
        luaH_warn(L, "unknown property: %s", luaL_checkstring(L, 2));
        return 0;
    }
    return luaH_object_property_signal(L, 1, token);
}

static void
activate_cb(GtkEntry* UNUSED(e), widget_t *w)
{
    lua_State *L = common.L;
    luaH_object_push(L, w->ref);
    luaH_object_emit_signal(L, -1, "activate", 0, 0);
    lua_pop(L, 1);
}

static void
changed_cb(widget_t *w)
{
    lua_State *L = common.L;
    luaH_object_push(L, w->ref);
    luaH_object_emit_signal(L, -1, "changed", 0, 0);
    lua_pop(L, 1);
}

static void
position_cb(GtkEntry* UNUSED(e), GParamSpec* UNUSED(ps), widget_t *w)
{
    lua_State *L = common.L;
    luaH_object_push(L, w->ref);
    luaH_object_emit_signal(L, -1, "property::position", 0, 0);
    lua_pop(L, 1);
}

widget_t *
widget_entry(lua_State *UNUSED(L), widget_t *w, luakit_token_t UNUSED(token))
{
    w->index = luaH_entry_index;
    w->newindex = luaH_entry_newindex;

    /* create gtk label widget as main widget */
    w->widget = gtk_entry_new();

    /* setup default settings */
#if GTK_CHECK_VERSION(3,4,0)
    GtkStyleContext *context = gtk_widget_get_style_context(GTK_WIDGET(w->widget));
    const gchar *inputbar_css = "GtkEntry {border: none; padding: 2px;}";

    GtkCssProvider *provider = gtk_css_provider_new();
    gtk_css_provider_load_from_data(provider, inputbar_css, strlen(inputbar_css), NULL);

    gtk_style_context_add_provider(context, GTK_STYLE_PROVIDER(provider), GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);
#else
    gtk_entry_set_inner_border(GTK_ENTRY(w->widget), NULL);
#endif

    g_object_connect(G_OBJECT(w->widget),
      LUAKIT_WIDGET_SIGNAL_COMMON(w)
      "signal::activate",                          G_CALLBACK(activate_cb),   w,
      "signal::key-press-event",                   G_CALLBACK(key_press_cb),  w,
      "signal::notify::cursor-position",           G_CALLBACK(position_cb),   w,
      NULL);

    // Further signal to replace "signal::changed"
    g_object_connect(G_OBJECT(w->widget),
      "swapped-signal::changed", G_CALLBACK(changed_cb), w,
      NULL);

    gtk_widget_show(w->widget);
    return w;
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
