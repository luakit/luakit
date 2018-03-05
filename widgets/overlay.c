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
luaH_overlay_pack(lua_State *L)
{
    widget_t *w = luaH_checkwidget(L, 1);
    widget_t *child = luaH_checkwidget(L, 2);

    gint top = lua_gettop(L);
    GtkAlign halign = GTK_ALIGN_FILL, valign = GTK_ALIGN_FILL;

    /* check for options table */
    if (top > 2 && !lua_isnil(L, 3)) {
        luaH_checktable(L, 3);

        if (luaH_rawfield(L, 3, "halign"))
            switch (l_tokenize(lua_tostring(L, -1))) {
                case L_TK_FILL:     halign = GTK_ALIGN_FILL;     break;
                case L_TK_START:    halign = GTK_ALIGN_START;    break;
                case L_TK_END:      halign = GTK_ALIGN_END;      break;
                case L_TK_CENTER:   halign = GTK_ALIGN_CENTER;   break;
                case L_TK_BASELINE: halign = GTK_ALIGN_BASELINE; break;
                default:
                    return luaL_error(L, "Bad alignment value (expected fill, start, end, center, or baseline)");
            }

        if (luaH_rawfield(L, 3, "valign"))
            switch (l_tokenize(lua_tostring(L, -1))) {
                case L_TK_FILL:     valign = GTK_ALIGN_FILL;     break;
                case L_TK_START:    valign = GTK_ALIGN_START;    break;
                case L_TK_END:      valign = GTK_ALIGN_END;      break;
                case L_TK_CENTER:   valign = GTK_ALIGN_CENTER;   break;
                case L_TK_BASELINE: valign = GTK_ALIGN_BASELINE; break;
                default:
                    return luaL_error(L, "Bad alignment value (expected fill, start, end, center, or baseline)");
            }

        /* return stack to original state */
        lua_settop(L, top);
    }

    gtk_widget_set_halign(GTK_WIDGET(child->widget), halign);
    gtk_widget_set_valign(GTK_WIDGET(child->widget), valign);
    gtk_overlay_add_overlay(GTK_OVERLAY(w->widget), GTK_WIDGET(child->widget));
    return 0;
}

static gint
luaH_overlay_reorder_child(lua_State *L)
{
    widget_t *w = luaH_checkwidget(L, 1);
    widget_t *child = luaH_checkwidget(L, 2);
    gint pos = luaL_checknumber(L, 3);
    gtk_overlay_reorder_overlay(GTK_OVERLAY(w->widget), GTK_WIDGET(child->widget), pos);
    return 0;
}

static gint
luaH_overlay_index(lua_State *L, widget_t *w, luakit_token_t token)
{
    switch(token) {
      LUAKIT_WIDGET_INDEX_COMMON(w)
      LUAKIT_WIDGET_BIN_INDEX_COMMON(w)
      LUAKIT_WIDGET_CONTAINER_INDEX_COMMON(w)

      /* push class methods */
      PF_CASE(PACK,         luaH_overlay_pack)
      PF_CASE(REORDER,      luaH_overlay_reorder_child)

      default:
        break;
    }
    return 0;
}

static gint
luaH_overlay_newindex(lua_State *L, widget_t *w, luakit_token_t token)
{
    switch(token) {
      LUAKIT_WIDGET_NEWINDEX_COMMON(w)
      LUAKIT_WIDGET_BIN_NEWINDEX_COMMON(w)

      default:
        return 0;
    }

    return luaH_object_property_signal(L, 1, token);
}

widget_t *
widget_overlay(lua_State *UNUSED(L), widget_t *w, luakit_token_t UNUSED(token))
{
    w->index = luaH_overlay_index;
    w->newindex = luaH_overlay_newindex;

#if GTK_CHECK_VERSION(3,2,0)
    w->widget = gtk_overlay_new();
#endif

    g_object_connect(G_OBJECT(w->widget),
        LUAKIT_WIDGET_SIGNAL_COMMON(w)
        NULL);

    gtk_widget_show(w->widget);
    return w;
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
