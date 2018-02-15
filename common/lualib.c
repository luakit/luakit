/*
 * common/lualib.c - useful functions and type for Lua
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

#include "common/lualib.h"

/** Dump the Lua stack. Useful for debugging.
 * \param L The Lua VM state.
 */
void
luaH_dump_stack(lua_State *L)
{
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
          case LUA_TUSERDATA:
            g_fprintf(stderr, "%d: <%s>\t\t%p\n", i, luaH_typename(L, i), lua_topointer(L, i));
            break;
          case LUA_TTABLE:
            g_fprintf(stderr, "%d: table\t#%zu\t%p\n", i, lua_objlen(L, i), lua_topointer(L, i));
            luaH_dump_table_keys(L, i);
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

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
