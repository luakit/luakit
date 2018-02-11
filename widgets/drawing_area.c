/*
 * Copyright © 2017 Aidan Holm <aidanholm@gmail.com>
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

static gpointer ffi_new_ref;

static gint
luaH_drawing_area_invalidate(lua_State *L)
{
    widget_t *w = luaH_checkwidget(L, 1);
    guint width = gtk_widget_get_allocated_width(w->widget);
    guint height = gtk_widget_get_allocated_height(w->widget);
    gtk_widget_queue_draw_area(w->widget, 0, 0, width, height);
    return 0;
}

static gint
luaH_drawing_area_index(lua_State *L, widget_t *w, luakit_token_t token)
{
    switch(token) {
      LUAKIT_WIDGET_INDEX_COMMON(w)
        PF_CASE(INVALIDATE, luaH_drawing_area_invalidate)
      default:
        break;
    }
    return 0;
}

static gint
luaH_drawing_area_newindex(lua_State *L, widget_t *w, luakit_token_t token)
{
    switch(token) {
      LUAKIT_WIDGET_NEWINDEX_COMMON(w)
      default:
        break;
    }

    return luaH_object_property_signal(L, 1, token);
}

static gboolean
drawing_area_draw_cb(GtkWidget *UNUSED(widget), cairo_t *cr, widget_t *w)
{
    lua_State *L = common.L;
    luaH_object_push(L, w->ref);
    /* Convert cr to a FFI wrapper */
    luaH_object_push(L, ffi_new_ref);
    lua_pushliteral(L, "cairo_t *");
    lua_pushlightuserdata(L, cr);
    gint error = lua_pcall(L, 2, 1, 0);
    g_assert(error == 0);
    luaH_object_emit_signal(L, -2, "draw", 1, 0);
    lua_pop(L, 1);
    return FALSE;
}

widget_t *
widget_drawing_area(lua_State *UNUSED(L), widget_t *w, luakit_token_t UNUSED(token))
{
    w->index = luaH_drawing_area_index;
    w->newindex = luaH_drawing_area_newindex;

    /* Store ref to ffi.new() */
    /* FIXME: Should do this before Lua code runs at all, but there's no good
     * way for random C code to hook into the Lua initialization stuff */
    if (!ffi_new_ref) {
        lua_State *L = common.L;
        lua_getglobal(L, "require");
        lua_pushliteral(L, "ffi");
        gint error = lua_pcall(L, 1, 1, 0);
        g_assert(error == 0);
        if (!lua_istable(L, -1))
            luaL_error(L, "Cannot create/use drawing area without ffi");
        lua_getfield(L, -1, "new");
        ffi_new_ref = luaH_object_ref(L, -1);
        lua_pop(L, 1);
    }

    w->widget = gtk_drawing_area_new();

    g_object_connect(G_OBJECT(w->widget),
        LUAKIT_WIDGET_SIGNAL_COMMON(w)
        "draw", G_CALLBACK(drawing_area_draw_cb), w,
        NULL);

    gtk_widget_show(w->widget);
    return w;
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
