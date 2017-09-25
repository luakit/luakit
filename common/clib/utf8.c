/*
 * common/clib/utf8.c - Basic UTF8 character counting (wrapper for glib)
 *
 * Copyright © 2017 Dennis Hofheinz <github@kjdf.de>
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

#include "common/clib/utf8.h"
#include "common/luaobject.h"
#include "luah.h"

#include <glib.h>

typedef struct {
    LUA_OBJECT_HEADER
} lutf8_t;

static lua_class_t utf8_class;
LUA_OBJECT_FUNCS(utf8_class, lutf8_t, utf8)

#define UTF8_STOPPED -1

#define luaH_checkutf8(L, idx) luaH_checkudata(L, idx, &(utf8_class))

static int
luaH_utf8_new(lua_State *L)
{
    luaH_class_new(L, &utf8_class);
    return 1;
}

/* UTF8 aware string length computing.
 * Returns the number of elements pushed on the stack. */
static gint
luaH_utf8_len(lua_State *L)
{
    const gchar *cmd = luaL_checkstring(L, 1);
    lua_pushnumber(L, (ssize_t) g_utf8_strlen(NONULL(cmd), -1));
    return 1;
}

/* UTF8 aware string offset conversion.
 * Converts (1-based) UTF8 offset to (1-based) byte offset.
 * Returns the number of elements pushed on the stack. */
static gint
luaH_utf8_offset(lua_State *L)
{
    const gchar *cmd = luaL_checkstring(L, 1);
    gint widx = luaL_checkint(L, 2);
    const gint len = g_utf8_strlen(NONULL(cmd), -1);
    gint ret = 0;

    /* convert negative to positive index */
    if(widx < 0 && -widx <= len)
        widx = len + widx + 1;

    /* convert positive UTF8 offset to byte offset */
    if(widx > 0 && widx <= len + 1) {
        gchar *pos = g_utf8_offset_to_pointer(NONULL(cmd), widx - 1);
        if (pos != NULL)
            ret = (gint) (pos - cmd) + 1;
    }

    /* imitate Lua 5.3 utf8.offset in corner case */
    if(widx == 0)
        ret = 1;

    /* if conversion was successful, output result (else output nil) */
    if(ret > 0)
        lua_pushnumber(L, (ssize_t) ret);
    else
        lua_pushnil(L);
    return 1;
}

void
utf8_class_setup(lua_State *L)
{
    static const struct luaL_Reg utf8_methods[] =
    {
        LUA_CLASS_METHODS(utf8)
        { "__call", luaH_utf8_new },
        { "len", luaH_utf8_len },
        { "offset", luaH_utf8_offset },
        { NULL, NULL }
    };

    static const struct luaL_Reg utf8_meta[] =
    {
        LUA_OBJECT_META(utf8)
        LUA_CLASS_META
        { NULL, NULL },
    };

    luaH_class_setup(L, &utf8_class, "utf8",
            (lua_class_allocator_t) utf8_new,
            NULL, NULL,
            utf8_methods, utf8_meta);
}

#undef luaH_checkutf8

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
