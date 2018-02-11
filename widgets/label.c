/*
 * widgets/label.c - gtk text area widget
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
luaH_label_get_align(lua_State *L, widget_t *w)
{
    gfloat xalign, yalign;
#if GTK_CHECK_VERSION(3,16,0)
    xalign = gtk_label_get_xalign(GTK_LABEL(w->widget));
    yalign = gtk_label_get_yalign(GTK_LABEL(w->widget));
#else
#  pragma GCC diagnostic push
#  pragma GCC diagnostic ignored "-Wdeprecated-declarations"
    gtk_misc_get_alignment(GTK_MISC(w->widget), &xalign, &yalign);
#  pragma GCC diagnostic pop
#endif
    luaH_widget_get_align(L, w);
    /* set align.x */
    lua_pushliteral(L, "x");
    lua_pushnumber(L, xalign);
    lua_rawset(L, -3);
    /* set align.y */
    lua_pushliteral(L, "y");
    lua_pushnumber(L, yalign);
    lua_rawset(L, -3);
    return 1;
}

static gint
luaH_label_set_align(lua_State *L, widget_t *w)
{
    luaH_widget_set_align(L, w);

    gfloat xalign, yalign;
    luaH_checktable(L, 3);
#if !GTK_CHECK_VERSION(3,16,0)
    /* get old alignment values */
    gtk_misc_get_alignment(GTK_MISC(w->widget), &xalign, &yalign);
#endif
    /* get align.x */
    if (luaH_rawfield(L, 3, "x")) {
        xalign = (gfloat) lua_tonumber(L, -1);
        lua_pop(L, 1);
#if GTK_CHECK_VERSION(3,16,0)
        gtk_label_set_xalign(GTK_LABEL(w->widget), xalign);
#endif
    }
    /* get align.y */
    if (luaH_rawfield(L, 3, "y")) {
        yalign = (gfloat) lua_tonumber(L, -1);
        lua_pop(L, 1);
#if GTK_CHECK_VERSION(3,16,0)
        gtk_label_set_yalign(GTK_LABEL(w->widget), yalign);
#endif
    }
#if !GTK_CHECK_VERSION(3,16,0)
    gtk_misc_set_alignment(GTK_MISC(w->widget), xalign, yalign);
#endif
    return 0;
}

#if !GTK_CHECK_VERSION(3,14,0)
static gint
luaH_label_get_padding(lua_State *L, widget_t *w)
{
    gint xpad, ypad;
    gtk_misc_get_padding(GTK_MISC(w->widget), &xpad, &ypad);
    lua_createtable(L, 0, 2);
    /* set padding.x */
    lua_pushliteral(L, "x");
    lua_pushnumber(L, xpad);
    lua_rawset(L, -3);
    /* set padding.y */
    lua_pushliteral(L, "y");
    lua_pushnumber(L, ypad);
    lua_rawset(L, -3);
    return 1;
}

static gint
luaH_label_set_padding(lua_State *L, widget_t *w)
{
    luaH_checktable(L, 3);
    /* get old padding values */
    gint xpad = 0, ypad = 0;
    gtk_misc_get_padding(GTK_MISC(w->widget), &xpad, &ypad);
    /* get padding.x */
    if (luaH_rawfield(L, 3, "x")) {
        xpad = (gint) lua_tonumber(L, -1);
        lua_pop(L, 1);
    }
    /* get padding.y */
    if (luaH_rawfield(L, 3, "y")) {
        ypad = (gint) lua_tonumber(L, -1);
        lua_pop(L, 1);
    }
    gtk_misc_set_padding(GTK_MISC(w->widget), xpad, ypad);
    return 0;
}
#endif

static gint
luaH_label_index(lua_State *L, widget_t *w, luakit_token_t token)
{
    if (token == L_TK_ALIGN)
        return luaH_label_get_align(L, w);

    switch(token) {
      LUAKIT_WIDGET_INDEX_COMMON(w)

#if !GTK_CHECK_VERSION(3,14,0)
      case L_TK_PADDING:
        return luaH_label_get_padding(L, w);
#endif

      /* push string properties */
      PS_CASE(FG,               g_object_get_data(G_OBJECT(w->widget), "fg"))
      PS_CASE(BG,               g_object_get_data(G_OBJECT(w->widget), "bg"))
      PS_CASE(FONT,             g_object_get_data(G_OBJECT(w->widget), "font"))
      PS_CASE(TEXT,             gtk_label_get_label(GTK_LABEL(w->widget)))
      /* push boolean properties */
      PB_CASE(SELECTABLE,       gtk_label_get_selectable(GTK_LABEL(w->widget)))
      /* push integer properties */
      PI_CASE(TEXTWIDTH,        gtk_label_get_width_chars(GTK_LABEL(w->widget)))

      default:
        break;
    }
    return 0;
}

static gint
luaH_label_newindex(lua_State *L, widget_t *w, luakit_token_t token)
{
    size_t len;
    const gchar *tmp;
    GdkRGBA c;
    PangoFontDescription *font;

    if (token == L_TK_ALIGN)
        return luaH_label_set_align(L, w);

    switch(token) {
      LUAKIT_WIDGET_NEWINDEX_COMMON(w)

#if !GTK_CHECK_VERSION(3,14,0)
      case L_TK_PADDING:
        return luaH_label_set_padding(L, w);
#endif

      case L_TK_TEXT:
        gtk_label_set_markup(GTK_LABEL(w->widget),
            luaL_checklstring(L, 3, &len));
        break;

      case L_TK_FG:
        tmp = luaL_checklstring(L, 3, &len);
        if (!gdk_rgba_parse(&c, tmp))
            luaL_argerror(L, 3, "unable to parse color");

#if GTK_CHECK_VERSION(3,16,0)
        widget_set_css_properties(w, "color", tmp, NULL);
#else
        gtk_widget_override_color(GTK_WIDGET(w->widget), GTK_STATE_FLAG_NORMAL, &c);
#endif
        g_object_set_data_full(G_OBJECT(w->widget), "fg", g_strdup(tmp), g_free);
        break;

      case L_TK_BG:
        tmp = luaL_checklstring(L, 3, &len);
        if (!gdk_rgba_parse(&c, tmp))
            luaL_argerror(L, 3, "unable to parse color");

#if GTK_CHECK_VERSION(3,16,0)
        widget_set_css_properties(w, "background-color", tmp, NULL);
#else
        gtk_widget_override_background_color(GTK_WIDGET(w->widget), GTK_STATE_FLAG_NORMAL, &c);
#endif
        g_object_set_data_full(G_OBJECT(w->widget), "bg", g_strdup(tmp), g_free);
        break;

      case L_TK_FONT:
        tmp = luaL_checklstring(L, 3, &len);
        font = pango_font_description_from_string(tmp);
#if GTK_CHECK_VERSION(3,16,0)
        widget_set_css_properties(w, "font", tmp, NULL);
#else
        gtk_widget_override_font(GTK_WIDGET(w->widget), font);
#endif
        pango_font_description_free(font);
        g_object_set_data_full(G_OBJECT(w->widget), "font", g_strdup(tmp), g_free);
        break;

      case L_TK_SELECTABLE:
        gtk_label_set_selectable(GTK_LABEL(w->widget), luaH_checkboolean(L, 3));
        break;

      case L_TK_TEXTWIDTH:
        gtk_label_set_width_chars(GTK_LABEL(w->widget),
                (gint)luaL_checknumber(L, 3));
        break;

      default:
        luaH_warn(L, "unknown property: %s", luaL_checkstring(L, 2));
        return 0;
    }

    return luaH_object_property_signal(L, 1, token);
}

widget_t *
widget_label(lua_State *UNUSED(L), widget_t *w, luakit_token_t UNUSED(token))
{
    w->index = luaH_label_index;
    w->newindex = luaH_label_newindex;

    /* create gtk label widget as main widget */
    w->widget = gtk_label_new(NULL);
    gtk_label_set_ellipsize(GTK_LABEL(w->widget), PANGO_ELLIPSIZE_END);

    /* setup default settings */
    gtk_label_set_selectable(GTK_LABEL(w->widget), FALSE);
    gtk_label_set_use_markup(GTK_LABEL(w->widget), TRUE);
#if GTK_CHECK_VERSION(3,14,0)
    gtk_widget_set_halign(GTK_WIDGET(w->widget), GTK_ALIGN_START);
    gtk_widget_set_valign(GTK_WIDGET(w->widget), GTK_ALIGN_START);

    GValue margin = G_VALUE_INIT;
    g_value_init(&margin, G_TYPE_INT);
    g_value_set_int(&margin, 2);
    g_object_set_property(G_OBJECT(w->widget), "margin", &margin);
#else
    gtk_misc_set_alignment(GTK_MISC(w->widget), 0, 0);
    gtk_misc_set_padding(GTK_MISC(w->widget), 2, 2);
#endif

    g_object_connect(G_OBJECT(w->widget),
      LUAKIT_WIDGET_SIGNAL_COMMON(w)
      "signal::key-press-event",   G_CALLBACK(key_press_cb),  w,
      NULL);

    gtk_widget_show(w->widget);
    return w;
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
