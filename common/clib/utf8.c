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
#include "luah.h"

#include <glib.h>

/* Convert 1-based into 0-based byte offset,
 * counted from back of string if negative
 * return -1 if offset is out of range */
static ssize_t
luaH_utf8_convert_offset(ssize_t offset, ssize_t length) {
    if(offset > 0)
        offset--;
    if(offset < 0)
        offset += length;
    if(offset < 0 || offset > length)
        return -1;
    return offset;
}

/* UTF8 aware string length computing.
 * Returns the number of elements pushed on the stack. */
static gint
luaH_utf8_len(lua_State *L)
{
    ssize_t blen;
    const gchar *str = luaL_checklstring(L, 1, &blen);
    gchar *valend;
    ssize_t bbeg, bend;

    /* parse optional begin/end parameters
     * imitate Lua 5.3: raise an error if out of bounds
     */
    bbeg = luaL_optinteger(L, 2, 1);
    bbeg = luaH_utf8_convert_offset(bbeg, blen);
    luaL_argcheck(L, bbeg != -1, 2, "initial position out of string");
    bend = luaL_optinteger(L, 3, blen) + 1;
    bend = luaH_utf8_convert_offset(bend, blen);
    luaL_argcheck(L, bend != -1, 3, "final position out of string");
    if(bend < bbeg)
        bend = blen;

    /* is the string valid UTF8? */
    if(!g_utf8_validate(str + bbeg, bend - bbeg, (const gchar **) &valend)) {
        lua_pushnil(L);
        lua_pushinteger(L, (ssize_t) (valend - str) + 1);
        return 2;
    }

    lua_pushinteger(L, (ssize_t) g_utf8_strlen(str + bbeg, bend - bbeg));
    return 1;
}

/* UTF8 aware string offset conversion.
 * Converts (1-based) UTF8 offset to (1-based) byte offset.
 * Returns the number of elements pushed on the stack. */
static gint
luaH_utf8_offset(lua_State *L)
{
    ssize_t blen;
    const gchar *str = luaL_checklstring(L, 1, &blen);
    ssize_t widx = luaL_checkinteger(L, 2);
    if(widx > 0) widx--; /* adjust to 0-based */
    ssize_t bbase;
    ssize_t ret = 0;
    ssize_t bbeg = 0;
    ssize_t wseglen;

    /* parse optional parameter (base index)
     * imitate Lua 5.3: raise an error if out of bounds
     * or if initial position points inside a UTF8 encoding */
    bbase = luaL_optinteger(L, 3, (widx>=0) ? 1 : blen + 1);
    bbase = luaH_utf8_convert_offset(bbase, blen);
    luaL_argcheck(L, bbase != -1, 3, "position out of range");
    if(g_utf8_get_char_validated(str + bbase, -1) == (gunichar) -1)
        luaL_error(L, "initial position is a continuation byte");

    /* convert negative index parameter to positive */
    if(widx < 0) {
        wseglen = g_utf8_strlen(str, bbase);
        widx += wseglen;
    } else {
        wseglen = g_utf8_strlen(str + bbase, blen - bbase);
        bbeg = bbase;
    }

    /* convert positive UTF8 offset to byte offset */
    if(widx >= 0 && widx <= wseglen) {
        gchar *pos = g_utf8_offset_to_pointer(str + bbeg, widx);
        if (pos != NULL)
            ret = (ssize_t) (pos - str) + 1;
    }

    /* if conversion was successful, output result (else output nil) */
    if(ret > 0)
        lua_pushinteger(L, ret);
    else
        lua_pushnil(L);
    return 1;
}

void
utf8_lib_setup(lua_State *L)
{
    static const struct luaL_Reg utf8_lib[] =
    {
        { "len", luaH_utf8_len },
        { "offset", luaH_utf8_offset },
        { NULL,              NULL }
    };

    luaH_openlib(L, "utf8", utf8_lib, utf8_lib);
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
