/*
 * common/lualib.h - useful functions and type for Lua
 *
 * Copyright © 2010 Mason Larobina <mason.larobina@gmail.com>
 * Copyright © 2009 Julien Danjou <julien@danjou.info>
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

#ifndef LUAKIT_COMMON_LUALIB_H
#define LUAKIT_COMMON_LUALIB_H

#include <glib/gprintf.h>
#include <lauxlib.h>
#include <lua.h>
#include <lualib.h>

#include "common/util.h"
#include "common/luautil.h"
#include "common/luaclass.h"

#define luaH_checkfunction(L, n) do { \
        if(!lua_isfunction(L, n)) \
            luaL_typerror(L, n, "function"); \
    } while(0)

/** Dump the Lua function call stack. Useful for debugging.
 * \param L The Lua VM state.
 */
static inline void
luaH_dump_traceback(lua_State *L)
{
    g_fprintf(stderr, "--------- Lua traceback ---------\n");
    luaH_traceback(L, L, 0);
    g_fprintf(stderr, "%s\n", lua_tostring(L, -1));
    lua_pop(L, 1);
    g_fprintf(stderr, "-------- Lua traceback end ------\n");
}

static inline void
luaH_dump_table_keys(lua_State *L, gint idx)
{
    gint len = (gint)lua_objlen(L, idx);
    guint limit = 5, rem = 0;

    g_fprintf(stderr, "  Keys: ");

    lua_pushvalue(L, idx);
    lua_pushnil(L);
    while (lua_next(L, -2)) {
        if (limit == 0)
            rem++;
        else {
            limit --;
            gint key_type = lua_type(L, -2);
            if (key_type == LUA_TNUMBER && lua_tointeger(L, -2) > len)
                g_fprintf(stderr, "%zd, ", lua_tointeger(L, -2));
            else if (key_type == LUA_TSTRING)
                g_fprintf(stderr, "%s, ", lua_tostring(L, -2));
            else
                g_fprintf(stderr, "[%s]", lua_typename(L, key_type));
        }

        lua_pop(L, 1);
    }
    lua_pop(L, 1);

    g_fprintf(stderr, "and %d more\n", rem);
}

void luaH_dump_stack(lua_State *L);

/** Convert s stack index to positive.
 * \param L The Lua VM state.
 * \param ud The index.
 * \return A positive index.
 */
static inline gint
luaH_absindex(lua_State *L, gint ud) {
    return (ud >= 0 || ud <= LUA_REGISTRYINDEX) ? ud : lua_gettop(L) + ud + 1;
}

/** Execute an Lua function on top of the stack.
 * \param L The Lua stack.
 * \param nargs The number of arguments for the Lua function.
 * \param nret The number of returned value from the Lua function.
 * \return True on no error, false otherwise.
 */
static inline gboolean
luaH_dofunction(lua_State *L, gint nargs, gint nret) {
    /* Move function before arguments */
    lua_insert(L, - nargs - 1);
    /* Push error handling function */
    lua_pushcfunction(L, luaH_dofunction_on_error);
    /* Move error handling function before args and function */
    lua_insert(L, - nargs - 2);
    gint error_func_pos = lua_gettop(L) - nargs - 1;
    if(lua_pcall(L, nargs, nret, - nargs - 2)) {
        error("%s", lua_tostring(L, -1));
        /* Remove error function and error string */
        lua_pop(L, 2);
        return FALSE;
    }
    /* Remove error function */
    lua_remove(L, error_func_pos);
    return TRUE;
}

#define luaH_checktable(L, n) do { \
        if(!lua_istable(L, n)) \
            luaL_typerror(L, n, "table"); \
    } while(0)

#endif

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
