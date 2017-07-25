/*
 * common/luah.c - Lua helper functions
 *
 * Copyright © 2010-2011 Mason Larobina <mason.larobina@gmail.com>
 * Copyright © 2008-2009 Julien Danjou <julien@danjou.info>
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

#include "common/luah.h"
#include "common/luautil.h"
#include "common/luaclass.h"
#include <gtk/gtk.h>
#include <lauxlib.h>

/* UTF-8 aware string length computing.
 * Returns the number of elements pushed on the stack. */
static gint
luaH_utf8_strlen(lua_State *L)
{
    const gchar *cmd  = luaL_checkstring(L, 1);
    lua_pushnumber(L, (ssize_t) g_utf8_strlen(NONULL(cmd), -1));
    return 1;
}

/* Overload standard Lua next function to use __next key on metatable.
 * Returns the number of elements pushed on stack. */
static gint
luaHe_next(lua_State *L)
{
    if(luaL_getmetafield(L, 1, "__next")) {
        lua_insert(L, 1);
        lua_call(L, lua_gettop(L) - 1, LUA_MULTRET);
        return lua_gettop(L);
    }
    luaL_checktype(L, 1, LUA_TTABLE);
    lua_settop(L, 2);
    if(lua_next(L, 1))
        return 2;
    lua_pushnil(L);
    return 1;
}

/* Overload lua_next() function by using __next metatable field to get
 * next elements. `idx` is the index number of elements in stack.
 * Returns 1 if more elements to come, 0 otherwise. */
gint
luaH_mtnext(lua_State *L, gint idx)
{
    if(luaL_getmetafield(L, idx, "__next")) {
        /* if idx is relative, reduce it since we got __next */
        if(idx < 0) idx--;
        /* copy table and then move key */
        lua_pushvalue(L, idx);
        lua_pushvalue(L, -3);
        lua_remove(L, -4);
        lua_pcall(L, 2, 2, 0);
        /* next returned nil, it's the end */
        if(lua_isnil(L, -1)) {
            /* remove nil */
            lua_pop(L, 2);
            return 0;
        }
        return 1;
    }
    else if(lua_istable(L, idx))
        return lua_next(L, idx);
    /* remove the key */
    lua_pop(L, 1);
    return 0;
}

/* Generic pairs function.
 * Returns the number of elements pushed on stack. */
static gint
luaH_generic_pairs(lua_State *L)
{
    lua_pushvalue(L, lua_upvalueindex(1));  /* return generator, */
    lua_pushvalue(L, 1);  /* state, */
    lua_pushnil(L);  /* and initial value */
    return 3;
}

/* Overload standard pairs function to use __pairs field of metatables.
 * Returns the number of elements pushed on stack. */
static gint
luaHe_pairs(lua_State *L)
{
    if(luaL_getmetafield(L, 1, "__pairs")) {
        lua_insert(L, 1);
        lua_call(L, lua_gettop(L) - 1, LUA_MULTRET);
        return lua_gettop(L);
    }
    luaL_checktype(L, 1, LUA_TTABLE);
    return luaH_generic_pairs(L);
}

static gint
luaH_ipairs_aux(lua_State *L)
{
    gint i = luaL_checkint(L, 2) + 1;
    luaL_checktype(L, 1, LUA_TTABLE);
    lua_pushinteger(L, i);
    lua_rawgeti(L, 1, i);
    return (lua_isnil(L, -1)) ? 0 : 2;
}

/* Overload standard ipairs function to use __ipairs field of metatables.
 * Returns the number of elements pushed on stack. */
static gint
luaHe_ipairs(lua_State *L)
{
    if(luaL_getmetafield(L, 1, "__ipairs")) {
        lua_insert(L, 1);
        lua_call(L, lua_gettop(L) - 1, LUA_MULTRET);
        return lua_gettop(L);
    }

    luaL_checktype(L, 1, LUA_TTABLE);
    lua_pushvalue(L, lua_upvalueindex(1));
    lua_pushvalue(L, 1);
    lua_pushinteger(L, 0);  /* and initial value */
    return 3;
}

/* Enhanced type() function which recognize luakit objects.
 * \param L The Lua VM state.
 * \return The number of arguments pushed on the stack.
 */
static gint
luaHe_type(lua_State *L)
{
    luaL_checkany(L, 1);
    lua_pushstring(L, luaH_typename(L, 1));
    return 1;
}

/** Returns the absolute version of a relative file path, if that file exists.
 *
 * \param  L The Lua VM state.
 * \return   The number of elements pushed on the stack.
 *
 * \luastack
 * \lparam rel_path The relative file path to convert.
 * \lreturn         Returns the full path of the given file.
 */
static gint
luaH_abspath(lua_State *L)
{
    const gchar *path = luaL_checkstring(L, 1);
    GFile *file = g_file_new_for_path(path);
    if (!file)
        return 0;
    gchar *absolute = g_file_get_path(file);
    if (!absolute)
        return 0;
    lua_pushstring(L, absolute);
    g_free(absolute);
    return 1;
}

static gint
luaH_debug_traceback(lua_State *L)
{
    lua_State *thread;
    if ((thread = lua_tothread(L, 1)))
        lua_remove(L, 1);
    const gchar *msg = luaL_optstring(L, 1, NULL);
    int level = luaL_optnumber(L, msg ? 2 : 1, 1);

    lua_pushstring(L, msg ?: "");
    lua_pushstring(L, msg ? "\nTraceback:\n" : "Traceback:\n");
    luaH_traceback(L, thread ?: L, level);
    gchar *stripped = strip_ansi_escapes(lua_tostring(L, -1));
    lua_pop(L, 1);
    lua_pushstring(L, stripped);
    lua_concat(L, 3);
    g_free(stripped);
    return 1;
}

/* Fix up and add handy standard lib functions */
void
luaH_fixups(lua_State *L)
{
    /* export string.wlen */
    lua_getglobal(L, "string");
    lua_pushcfunction(L, &luaH_utf8_strlen);
    lua_setfield(L, -2, "wlen");
    lua_pop(L, 1);
    /* export os.abspath */
    lua_getglobal(L, "os");
    lua_pushcfunction(L, &luaH_abspath);
    lua_setfield(L, -2, "abspath");
    lua_pop(L, 1);
    /* replace next */
    lua_pushliteral(L, "next");
    lua_pushcfunction(L, luaHe_next);
    lua_settable(L, LUA_GLOBALSINDEX);
    /* replace pairs */
    lua_pushliteral(L, "pairs");
    lua_pushcfunction(L, luaHe_next);
    lua_pushcclosure(L, luaHe_pairs, 1); /* pairs get next as upvalue */
    lua_settable(L, LUA_GLOBALSINDEX);
    /* replace ipairs */
    lua_pushliteral(L, "ipairs");
    lua_pushcfunction(L, luaH_ipairs_aux);
    lua_pushcclosure(L, luaHe_ipairs, 1);
    lua_settable(L, LUA_GLOBALSINDEX);
    /* replace type */
    lua_pushliteral(L, "type");
    lua_pushcfunction(L, luaHe_type);
    lua_settable(L, LUA_GLOBALSINDEX);
    /* replace debug.traceback */
    lua_getglobal(L, "debug");
    lua_pushcfunction(L, &luaH_debug_traceback);
    lua_setfield(L, -2, "traceback");
    lua_pop(L, 1);
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
