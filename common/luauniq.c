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

#include "common/luauniq.h"
#include "common/lualib.h"

#define LUAKIT_UNIQ_REGISTRY_KEY "luakit.uniq.registry"

/* Setup the unique object system at startup. */
void
luaH_uniq_setup(lua_State *L, const gchar *reg, const gchar *mode)
{
    /* Push identification string */
    lua_pushstring(L, reg ?: LUAKIT_UNIQ_REGISTRY_KEY);
    /* Create an empty table */
    lua_newtable(L);
    /* Set metatable specifying weak-values mode */
    lua_newtable(L);
    lua_pushstring(L, "__mode");
    lua_pushstring(L, mode);
    lua_rawset(L, -3);
    lua_setmetatable(L, -2);
    /* Register table inside registry */
    lua_rawset(L, LUA_REGISTRYINDEX);
}

/* Adds a key -> Lua value mapping.
 * The key must not already be mapped to a value.
 * The stack is left unmodified,
 * `oud` is the Lua value index on the stack. */
int
luaH_uniq_add(lua_State *L, const gchar *reg, int k, int oud)
{
    /* Push the registry */
    lua_pushstring(L, reg ?: LUAKIT_UNIQ_REGISTRY_KEY);
    lua_rawget(L, LUA_REGISTRYINDEX);

    /* Assert that the value is not already there */
    lua_pushvalue(L, k > 0 ? k : k-1);
    lua_rawget(L, -2);
    g_assert(lua_isnil(L, -1));
    lua_pop(L, 1);

    /* Add the Lua value */
    lua_pushvalue(L, k > 0 ? k : k-1);
    lua_pushvalue(L, oud < 0 ? oud - 2 : oud);
    lua_rawset(L, -3);

    /* Remove the registry */
    lua_pop(L, 1);
    return 0;
}

int
luaH_uniq_add_ptr(lua_State *L, const gchar *reg, gpointer key, int oud)
{
    lua_pushlightuserdata(L, key);
    luaH_uniq_add(L, reg, -1, oud > 0 ? oud : oud-1);
    lua_pop(L, 1);
    return 0;
}

/* Given a key, pushes its associated Lua value onto the stack,
 * if it exists */
int
luaH_uniq_get(lua_State *L, const gchar *reg, int k)
{
    /* Push the registry */
    lua_pushstring(L, reg ?: LUAKIT_UNIQ_REGISTRY_KEY);
    lua_rawget(L, LUA_REGISTRYINDEX);

    /* Get the Lua value */
    lua_pushvalue(L, k > 0 ? k : k-1);
    lua_rawget(L, -2);

    /* Remove the registry */
    lua_remove(L, -2);

    if (lua_isnil(L, -1)) {
        lua_pop(L, 1);
        return 0;
    }

    return 1;
}

int
luaH_uniq_get_ptr(lua_State *L, const gchar *reg, gpointer key)
{
    lua_pushlightuserdata(L, key);
    int n = luaH_uniq_get(L, reg, -1);
    lua_remove(L, -1-n);
    return n;
}

void
luaH_uniq_del(lua_State *L, const gchar *reg, int k)
{
    /* Push the registry */
    lua_pushstring(L, reg ?: LUAKIT_UNIQ_REGISTRY_KEY);
    lua_rawget(L, LUA_REGISTRYINDEX);

    /* Assert that the value is there */
    lua_pushvalue(L, k > 0 ? k : k-1);
    lua_rawget(L, -2);
    g_assert(!lua_isnil(L, -1));
    lua_pop(L, 1);

    /* Remove the Lua value */
    lua_pushvalue(L, k > 0 ? k : k-1);
    lua_pushnil(L);
    lua_rawset(L, -3);

    /* Remove the registry */
    lua_pop(L, 1);
}

void
luaH_uniq_del_ptr(lua_State *L, const gchar *reg, gpointer key)
{
    lua_pushlightuserdata(L, key);
    luaH_uniq_del(L, reg, -1);
    lua_pop(L, 1);
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
