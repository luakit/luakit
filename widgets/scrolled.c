/*
 * Copyright © 2016 Aidan Holm <aidanholm@gmail.com>
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
gtk_policy_from_string(const gchar *str, GtkPolicyType *out)
{
    if (!strcmp(str, "always"))
        *out = GTK_POLICY_ALWAYS;
    else if (!strcmp(str, "auto"))
        *out = GTK_POLICY_AUTOMATIC;
    else if (!strcmp(str, "never"))
        *out = GTK_POLICY_NEVER;
#if GTK_CHECK_VERSION(3,16,0)
    else if (!strcmp(str, "external"))
        *out = GTK_POLICY_EXTERNAL;
#endif
    else
        return 1;
    return 0;
}

static const gchar *
string_from_gtk_policy(GtkPolicyType policy)
{
    switch (policy) {
        case GTK_POLICY_ALWAYS:    return "always";
        case GTK_POLICY_AUTOMATIC: return "auto";
        case GTK_POLICY_NEVER:     return "never";
#if GTK_CHECK_VERSION(3,16,0)
        case GTK_POLICY_EXTERNAL:  return "external";
#endif
        default: return NULL;
    }
}

gint
luaH_widget_get_scrollbars(lua_State *L, widget_t *w)
{
    GtkPolicyType horz, vert;
    gtk_scrolled_window_get_policy(GTK_SCROLLED_WINDOW(w->widget), &horz, &vert);

    lua_newtable(L);

    lua_pushliteral(L, "h");
    lua_pushstring(L, string_from_gtk_policy(horz));
    lua_rawset(L, -3);

    lua_pushliteral(L, "v");
    lua_pushstring(L, string_from_gtk_policy(vert));
    lua_rawset(L, -3);

    return 1;
}

gint
luaH_widget_set_scrollbars(lua_State *L, widget_t *w)
{
    luaH_checktable(L, 3);

    GtkPolicyType horz, vert;
    gtk_scrolled_window_get_policy(GTK_SCROLLED_WINDOW(w->widget), &horz, &vert);

    gint top = lua_gettop(L);
    if (luaH_rawfield(L, 3, "h")) {
        if (gtk_policy_from_string(lua_tostring(L, -1), &horz))
            luaL_error(L, "Bad horizontal scrollbar policy");
    }
    if (luaH_rawfield(L, 3, "v")) {
        if (gtk_policy_from_string(lua_tostring(L, -1), &vert))
            luaL_error(L, "Bad vertical scrollbar policy");
    }
    lua_settop(L, top);

    gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(w->widget), horz, vert);
    return 1;
}

gint
luaH_scrolled_get_scroll(lua_State *L, widget_t *w)
{
    GtkAdjustment *horz = gtk_scrolled_window_get_hadjustment(GTK_SCROLLED_WINDOW(w->widget));
    GtkAdjustment *vert = gtk_scrolled_window_get_vadjustment(GTK_SCROLLED_WINDOW(w->widget));

    lua_newtable(L);

    lua_pushliteral(L, "x");
    lua_pushnumber(L, gtk_adjustment_get_value(horz));
    lua_rawset(L, -3);

    lua_pushliteral(L, "y");
    lua_pushnumber(L, gtk_adjustment_get_value(vert));
    lua_rawset(L, -3);

    lua_pushliteral(L, "xmax");
    lua_pushnumber(L, gtk_adjustment_get_upper(horz));
    lua_rawset(L, -3);

    lua_pushliteral(L, "ymax");
    lua_pushnumber(L, gtk_adjustment_get_upper(vert));
    lua_rawset(L, -3);

    return 1;
}

gint
luaH_scrolled_set_scroll(lua_State *L, widget_t *w)
{
    luaH_checktable(L, 3);

    GtkAdjustment *horz = gtk_scrolled_window_get_hadjustment(GTK_SCROLLED_WINDOW(w->widget));
    GtkAdjustment *vert = gtk_scrolled_window_get_vadjustment(GTK_SCROLLED_WINDOW(w->widget));

    gint top = lua_gettop(L);
    if (luaH_rawfield(L, 3, "x"))
        gtk_adjustment_set_value(horz, lua_tonumber(L, -1));
    if (luaH_rawfield(L, 3, "y"))
        gtk_adjustment_set_value(vert, lua_tonumber(L, -1));
    lua_settop(L, top);

    return 0;
}

static gint
luaH_scrolled_index(lua_State *L, widget_t *w, luakit_token_t token)
{
    switch(token) {
      LUAKIT_WIDGET_INDEX_COMMON(w)
      LUAKIT_WIDGET_BIN_INDEX_COMMON(w)
      LUAKIT_WIDGET_CONTAINER_INDEX_COMMON(w)

      case L_TK_SCROLLBARS:
        return luaH_widget_get_scrollbars(L, w);

      case L_TK_SCROLL:
        return luaH_scrolled_get_scroll(L, w);

      default:
        break;
    }
    return 0;
}

static gint
luaH_scrolled_newindex(lua_State *L, widget_t *w, luakit_token_t token)
{
    switch(token) {
      LUAKIT_WIDGET_NEWINDEX_COMMON(w)
      LUAKIT_WIDGET_BIN_NEWINDEX_COMMON(w)

      case L_TK_SCROLLBARS:
        luaH_widget_set_scrollbars(L, w);
        break;

      case L_TK_SCROLL:
        luaH_scrolled_set_scroll(L, w);
        break;

      default:
        break;
    }

    return luaH_object_property_signal(L, 1, token);
}

widget_t *
widget_scrolled(lua_State *UNUSED(L), widget_t *w, luakit_token_t UNUSED(token))
{
    w->index = luaH_scrolled_index;
    w->newindex = luaH_scrolled_newindex;

#if GTK_CHECK_VERSION(3,2,0)
    w->widget = gtk_scrolled_window_new(NULL, NULL);
#endif

    g_object_connect(G_OBJECT(w->widget),
        LUAKIT_WIDGET_SIGNAL_COMMON(w)
        NULL);

    gtk_widget_show(w->widget);
    return w;
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
