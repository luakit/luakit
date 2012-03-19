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
    gtk_misc_get_alignment(GTK_MISC(w->widget), &xalign, &yalign);
    lua_createtable(L, 0, 2);
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
    luaH_checktable(L, 3);
    /* get old alignment values */
    gfloat xalign, yalign;
    gtk_misc_get_alignment(GTK_MISC(w->widget), &xalign, &yalign);
    /* get align.x */
    if (luaH_rawfield(L, 3, "x")) {
        xalign = (gfloat) lua_tonumber(L, -1);
        lua_pop(L, 1);
    }
    /* get align.y */
    if (luaH_rawfield(L, 3, "y")) {
        yalign = (gfloat) lua_tonumber(L, -1);
        lua_pop(L, 1);
    }
    gtk_misc_set_alignment(GTK_MISC(w->widget), xalign, yalign);
    return 0;
}

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

static gint
luaH_label_index(lua_State *L, widget_t *w, luakit_token_t token)
{
    switch(token) {
      LUAKIT_WIDGET_INDEX_COMMON(w)

      case L_TK_PADDING:
        return luaH_label_get_padding(L, w);

      case L_TK_ALIGN:
        return luaH_label_get_align(L, w);

      /* push string properties */
      PS_CASE(FG,               g_object_get_data(G_OBJECT(w->widget), "fg"))
      PS_CASE(FONT,             g_object_get_data(G_OBJECT(w->widget), "font"))
      PS_CASE(TEXT,             gtk_label_get_label(GTK_LABEL(w->widget)))
      /* push boolean properties */
      PB_CASE(SELECTABLE,       gtk_label_get_selectable(GTK_LABEL(w->widget)))
      /* push integer properties */
      PI_CASE(WIDTH,            gtk_label_get_width_chars(GTK_LABEL(w->widget)))

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
    GdkColor c;
    PangoFontDescription *font;

    switch(token) {
      LUAKIT_WIDGET_NEWINDEX_COMMON(w)

      case L_TK_PADDING:
        return luaH_label_set_padding(L, w);

      case L_TK_ALIGN:
        return luaH_label_set_align(L, w);

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
        pango_font_description_free(font);
        g_object_set_data_full(G_OBJECT(w->widget), "font", g_strdup(tmp), g_free);
        break;

      case L_TK_SELECTABLE:
        gtk_label_set_selectable(GTK_LABEL(w->widget), luaH_checkboolean(L, 3));
        break;

      case L_TK_WIDTH:
        gtk_label_set_width_chars(GTK_LABEL(w->widget),
                (gint)luaL_checknumber(L, 3));
        return 0;

      default:
        warn("unknown property: %s", luaL_checkstring(L, 2));
        return 0;
    }

    return luaH_object_property_signal(L, 1, token);
}

widget_t *
widget_label(widget_t *w, luakit_token_t UNUSED(token))
{
    w->index = luaH_label_index;
    w->newindex = luaH_label_newindex;
    w->destructor = widget_destructor;

    /* create gtk label widget as main widget */
    w->widget = gtk_label_new(NULL);

    /* setup default settings */
    gtk_label_set_selectable(GTK_LABEL(w->widget), FALSE);
    gtk_label_set_use_markup(GTK_LABEL(w->widget), TRUE);
    gtk_misc_set_alignment(GTK_MISC(w->widget), 0, 0);
    gtk_misc_set_padding(GTK_MISC(w->widget), 2, 2);

    g_object_connect(G_OBJECT(w->widget),
      LUAKIT_WIDGET_SIGNAL_COMMON(w)
      "signal::key-press-event",   G_CALLBACK(key_press_cb),  w,
      NULL);

    gtk_widget_show(w->widget);
    return w;
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
