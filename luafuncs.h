/*
 * luafuncs.c - Lua functions
 *
 * Copyright (C) 2010 Mason Larobina <mason.larobina@gmail.com>
 * Copyright (C) 2008 Julien Danjou <julien@danjou.info>
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

/** Lua function to call on dofuction() error */
lua_CFunction lualib_dofunction_on_error;

#define luaH_checkfunction(L, n) \
    do { \
        if(!lua_isfunction(L, n)) \
            luaL_typerror(L, n, "function"); \
    } while(0)

void luaH_init(xdgHandle *xdg);
gboolean luaH_parserc(xdgHandle* xdg, const gchar *confpatharg, gboolean run);
