/*
 * lualib.h - useful functions and type for Lua
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

#ifndef LUAKIT_COMMON_LUALIB
#define LUAKIT_COMMON_LUALIB

#include <glib/gprintf.h>
#include <lauxlib.h>
#include <lua.h>
#include <lualib.h>

#include "common/util.h"

/** Lua function to call on dofuction() error */
lua_CFunction lualib_dofunction_on_error;

#define luaH_checkfunction(L, n) do { \
        if(!lua_isfunction(L, n)) \
            luaL_typerror(L, n, "function"); \
    } while(0)

/** Dump the Lua stack. Useful for debugging.
 * \param L The Lua VM state.
 */
static inline void
luaH_dumpstack(lua_State *L) {
    g_fprintf(stderr, "-------- Lua stack dump ---------\n");
    for(int i = lua_gettop(L); i; i--) {
        int t = lua_type(L, i);
        switch (t) {
          case LUA_TSTRING:
            g_fprintf(stderr, "%d: string: `%s'\n", i, lua_tostring(L, i));
            break;
          case LUA_TBOOLEAN:
            g_fprintf(stderr, "%d: bool:   %s\n", i, lua_toboolean(L, i) ? "true" : "false");
            break;
          case LUA_TNUMBER:
            g_fprintf(stderr, "%d: number: %g\n", i, lua_tonumber(L, i));
            break;
          case LUA_TNIL:
            g_fprintf(stderr, "%d: nil\n", i);
            break;
          default:
            g_fprintf(stderr, "%d: %s\t#%d\t%p\n", i, lua_typename(L, t),
                    (gint) lua_objlen(L, i),
                    lua_topointer(L, i));
            break;
        }
    }
    g_fprintf(stderr, "------- Lua stack dump end ------\n");
}

/** Convert s stack index to positive.
 * \param L The Lua VM state.
 * \param ud The index.
 * \return A positive index.
 */
static inline gint
luaH_absindex(lua_State *L, gint ud) {
    return (ud > 0 || ud <= LUA_REGISTRYINDEX) ? ud : lua_gettop(L) + ud + 1;
}

static inline gint
luaH_dofunction_error(lua_State *L) {
    if(lualib_dofunction_on_error)
        return lualib_dofunction_on_error(L);
    return 0;
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
    lua_pushcfunction(L, luaH_dofunction_error);
    /* Move error handling function before args and function */
    lua_insert(L, - nargs - 2);
    gint error_func_pos = lua_gettop(L) - nargs - 1;
    if(lua_pcall(L, nargs, nret, - nargs - 2)) {
        warn("%s", lua_tostring(L, -1));
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
